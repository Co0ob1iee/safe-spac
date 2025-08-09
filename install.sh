#!/usr/bin/env bash
set -euo pipefail

# Resolve script directory (so rsync works even when called via absolute path)
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd -P)"

# --- Color & UI helpers ---
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  ncolors=$(tput colors || echo 0)
else
  ncolors=0
fi

if [[ ${NO_COLOR:-} != 1 ]] && [[ $ncolors -ge 8 ]]; then
  C_RESET="\033[0m"; C_BOLD="\033[1m"
  C_INFO="\033[36m"; C_WARN="\033[33m"; C_ERR="\033[31m"; C_OK="\033[32m"; C_DIM="\033[2m"
else
  C_RESET=""; C_BOLD=""; C_INFO=""; C_WARN=""; C_ERR=""; C_OK=""; C_DIM=""
fi

info()    { printf "%b[INFO]%b %s\n"   "$C_INFO" "$C_RESET" "$*"; }
warn()    { printf "%b[WARN]%b %s\n"   "$C_WARN" "$C_RESET" "$*"; }
error()   { printf "%b[ERR ]%b %s\n"   "$C_ERR" "$C_RESET" "$*"; }
success() { printf "%b[ OK ]%b %s\n"   "$C_OK"  "$C_RESET" "$*"; }
step()    { printf "%b==>%b %s\n"       "$C_BOLD" "$C_RESET" "$*"; }

banner() {
  printf "\n%b🛰️  Safe‑Spac Installer%b\n" "$C_BOLD" "$C_RESET"
  printf "%b=====================%b\n\n" "$C_DIM" "$C_RESET"
}

banner

# safe-spac installer (production-ready)
# Usage (non-interactive):
#   PUBLIC_IP=<IP> ./install.sh
# or interactive: script zapyta o domenę/IP, podsieć WG i prywatny sufiks DNS

if [[ ${EUID} -ne 0 ]]; then
  echo "[ERR] Uruchom jako root" >&2
  exit 1
fi

# --- Interaktywne pytania ---
read -r -p "Czy masz domenę dla serwera (y/N)? " HAS_DOMAIN || true
HAS_DOMAIN=${HAS_DOMAIN:-N}
DOMAIN=""
ACME_EMAIL=""
if [[ ${HAS_DOMAIN} =~ ^[Yy]$ ]]; then
  read -r -p "Podaj domenę publiczną (np. safe.example.com): " DOMAIN
  read -r -p "E-mail do Let's Encrypt (akceptujesz TOS): " ACME_EMAIL
else
  PUBLIC_IP=${PUBLIC_IP:-}
  if [[ -z "${PUBLIC_IP}" ]]; then
    read -r -p "Podaj publiczne IP serwera: " PUBLIC_IP
  fi
fi

WG_SUBNET=${WG_SUBNET:-10.66.0.0/24}
WG_ADDR=${WG_ADDR:-10.66.0.1/24}
WG_PORT=${WG_PORT:-51820}
PRIVATE_SUFFIX=${PRIVATE_SUFFIX:-safe.lan}
FULL_TUNNEL=${FULL_TUNNEL:-}
INSTALL_ROOT=${INSTALL_ROOT:-/opt/safe-spac}
DATA_DIR="$INSTALL_ROOT/server/data"
AUTHELIA_DIR="$INSTALL_ROOT/authelia"
DNSMASQ_DIR="$INSTALL_ROOT/dnsmasq"
DNSMASQ_CONF_SRC="$DNSMASQ_DIR/dnsmasq.conf.tmpl"
DNSMASQ_CONF_DST="$DNSMASQ_DIR/dnsmasq.conf"

# --- Instalacja zależności systemowych ---
info "Instaluję zależności systemowe (curl, gnupg, lsb-release, apt-transport-https, ca-certificates)"
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release rsync iptables iproute2 dnsutils gettext-base unzip iptables-persistent

# Docker repo + compose-plugin
if ! command -v docker >/dev/null 2>&1; then
  echo "[INFO] Dodaję repo Docker i instaluję docker-ce + plugin compose"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
fi

# WireGuard tools
if ! command -v wg >/dev/null 2>&1; then
  echo "[INFO] Instaluję wireguard-tools"
  apt-get install -y wireguard-tools
fi

# --- Skopiowanie repo do /opt ---
mkdir -p "$INSTALL_ROOT"
rsync -a --delete --exclude .git --exclude build --exclude node_modules "$SCRIPT_DIR"/ "$INSTALL_ROOT"/

# --- Konfiguracja WireGuard ---
mkdir -p /etc/wireguard
if [[ ! -f /etc/wireguard/server.key ]]; then
  umask 077
  wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
fi
if [[ ! -f /etc/wireguard/admin.key ]]; then
  umask 077
  wg genkey | tee /etc/wireguard/admin.key | wg pubkey > /etc/wireguard/admin.pub
fi
cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${WG_ADDR}
ListenPort = ${WG_PORT}
PrivateKey = $(cat /etc/wireguard/server.key)
SaveConfig = true

# Forwarding/firewall reguły możesz dodać wg potrzeb (NAT itp.)
EOF

# Włącz i startuj WG
systemctl enable wg-quick@wg0 || true
systemctl restart wg-quick@wg0 || systemctl start wg-quick@wg0

# --- NAT / full-tunnel (opcjonalnie) ---
if [[ -z "$FULL_TUNNEL" ]]; then
  read -r -p "Czy chcesz włączyć full-tunnel (NAT przez VPS, AllowedIPs=0.0.0.0/0)? (y/N): " FULL_TUNNEL || true
fi

ALLOWED_IPS="10.66.0.0/24"
if [[ ${FULL_TUNNEL:-N} =~ ^[Yy]$ ]]; then
  success "Włączam IP forwarding i NAT dla ${WG_SUBNET}"
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  sed -i 's/^#\?net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf || true
  # wykrycie interfejsu WAN
  WAN_IF=$(ip route get 1.1.1.1 | awk '/dev/ {for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' | head -1)
  : "${WAN_IF:=eth0}"
  # reguły iptables (idempotentne)
  if ! iptables -t nat -C POSTROUTING -s "$WG_SUBNET" -o "$WAN_IF" -j MASQUERADE 2>/dev/null; then
    iptables -t nat -A POSTROUTING -s "$WG_SUBNET" -o "$WAN_IF" -j MASQUERADE
  fi
  if ! iptables -C FORWARD -i "$WAN_IF" -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i "$WAN_IF" -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
  fi
  if ! iptables -C FORWARD -i wg0 -o "$WAN_IF" -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i wg0 -o "$WAN_IF" -j ACCEPT
  fi
  # utrwal reguły
  netfilter-persistent save || true
  ALLOWED_IPS="0.0.0.0/0"
fi

# --- dnsmasq (render + kontener host-mode) ---
install -d -m 0755 "$DNSMASQ_DIR"
# Fallback: jeśli szablon nie istnieje (np. problem z rsync), utwórz domyślny
if [[ ! -f "$DNSMASQ_CONF_SRC" ]]; then
  cat >"$DNSMASQ_CONF_SRC" <<'TMPL'
# dnsmasq basic config for Safe‑Spac
no-resolv
domain-needed
bogus-priv
listen-address=127.0.0.1
listen-address=10.66.0.1

# Private suffix
local=/{{PRIVATE_SUFFIX}}/
domain={{PRIVATE_SUFFIX}}

# Internal hosts
address=/portal.{{PRIVATE_SUFFIX}}/10.66.0.1
address=/service.teamspeak/10.66.0.1
address=/service.git/10.66.0.1
TMPL
fi
sed "s/{{PRIVATE_SUFFIX}}/${PRIVATE_SUFFIX}/g" "$DNSMASQ_CONF_SRC" > "$DNSMASQ_CONF_DST"

# --- Authelia: generacja hasła admina ---
mkdir -p "$AUTHELIA_DIR"
ADMIN_EMAIL="admin@example.com"
if [[ ! -f "$AUTHELIA_DIR/users_database.yml" ]]; then
  step "Generuję losowe hasło admina Authelii"
  ADMIN_PASS=$(openssl rand -base64 18)
  HASH=$(docker run --rm authelia/authelia:4.38 authelia crypto hash generate argon2 --password "$ADMIN_PASS" | tail -1 | sed 's/^.*: //')
  # configuration.yml (jeśli nie istnieje)
  if [[ ! -f "$AUTHELIA_DIR/configuration.yml" ]]; then
    cp "$INSTALL_ROOT/server/authelia/configuration.yml" "$AUTHELIA_DIR/configuration.yml"
  fi
  cat > "$AUTHELIA_DIR/users_database.yml" <<YML
users:
  ${ADMIN_EMAIL}:
    displayname: Admin
    password: "${HASH}"
    email: ${ADMIN_EMAIL}
    groups:
      - admins
      - users
YML
  ADMIN_PASS_MSG="$ADMIN_PASS"
else
  ADMIN_PASS_MSG="<niezmienione – istniejący plik>"
fi

# --- Render docker-compose.yml ---
pushd "$INSTALL_ROOT/server" >/dev/null
sed \
  -e "s/{{PUBLIC_IP}}/${PUBLIC_IP:-}/g" \
  -e "s/{{WG_SUBNET}}/${WG_SUBNET//\//\\/}/g" \
  -e "s/{{ALLOWED_IPS}}/${ALLOWED_IPS//\//\\/}/g" \
  "$INSTALL_ROOT/server/docker-compose.yml.tmpl" > docker-compose.yml

# TLS override dla domeny (Traefik websecure + LE)
if [[ -n "$DOMAIN" ]]; then
  cat > docker-compose.override.yml <<OVR
version: "3.9"
services:
  traefik:
    command:
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.le.acme.tlschallenge=true
      - --certificatesresolvers.le.acme.email=${ACME_EMAIL}
      - --certificatesresolvers.le.acme.storage=/acme.json
    ports:
      - "443:443"
    volumes:
      - traefik-acme:/acme.json
  webapp:
    labels:
      - traefik.http.routers.webapp-public.rule=Host(`$DOMAIN`) && (PathPrefix(`/`) || PathPrefix(`/register`) || PathPrefix(`/invite`))
      - traefik.http.routers.webapp-public.entrypoints=websecure
      - traefik.http.routers.webapp-public.tls.certresolver=le
  core-api:
    labels:
      - traefik.http.routers.coreapi-public.rule=Host(`$DOMAIN`) && (PathPrefix(`/api/core/registration`) || PathPrefix(`/api/core/captcha`))
      - traefik.http.routers.coreapi-public.entrypoints=websecure
      - traefik.http.routers.coreapi-public.tls.certresolver=le
volumes:
  traefik-acme:
OVR
fi

# Uruchom stack (dnsmasq + reszta)
docker compose up -d

# Restart samego dnsmasq jeśli już był
(docker compose restart dnsmasq || true)

# Autostart cron @reboot
bash "$INSTALL_ROOT/scripts/install_cron.sh" || true
popd >/dev/null

# --- Admin WG klient ---
mkdir -p "$INSTALL_ROOT/tools"
sed "s/{{PUBLIC_IP}}/${PUBLIC_IP:-}/g" "$INSTALL_ROOT/tools/wg-client-sample.conf" > "$INSTALL_ROOT/tools/admin-wg.conf"

cat <<EON
[OK] Instalacja zakończona.
Tryb publiczny: $([[ -n "$DOMAIN" ]] && echo "https://$DOMAIN" || echo "http://${PUBLIC_IP:-<IP>}" )
Portal (VPN): http://portal.${PRIVATE_SUFFIX}

Dane konta Authelia:
- login: ${ADMIN_EMAIL}
- hasło: ${ADMIN_PASS_MSG}

Profil WireGuard admina:
- $INSTALL_ROOT/tools/admin-wg.conf

Uwaga:
- Jeśli używasz domeny, upewnij się, że rekord A wskazuje na IP serwera oraz port 80/443 są otwarte.
EON
