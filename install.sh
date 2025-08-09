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

# --- Preflight: sprawdź, czy porty 80/443 są wolne ---
check_port() {
  local p=$1
  if ss -tlnp 2>/dev/null | awk -v P=":${p}" '$4 ~ P {print}' | grep -q ":${p} "; then
    warn "Port ${p} jest aktualnie zajęty przez:" 
    ss -tlnp | awk -v P=":${p}" '$4 ~ P {print "  -", $0}'
    echo ""
    echo "Aby Traefik mógł wystartować, zwolnij port ${p}. Jeśli to nginx: systemctl stop nginx && systemctl disable nginx"
  else
    success "Port ${p} jest wolny"
  fi
}

check_port 80
check_port 443

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

# --- Opcje sterujące ---
# Ustaw FORCE_AUTHELIA_MINIMAL=1 aby nadpisać istniejący configuration.yml minimalną konfiguracją
FORCE_AUTHELIA_MINIMAL=${FORCE_AUTHELIA_MINIMAL:-0}
OIDC_ENABLE=${OIDC_ENABLE:-0}

# --- Instalacja zależności systemowych ---
info "Instaluję zależności systemowe (curl, gnupg, lsb-release, apt-transport-https, ca-certificates)"

# --- Spinner helpers ---
_spinner_pid=""
_stop_spinner() { [[ -n "${_spinner_pid}" ]] && kill "${_spinner_pid}" 2>/dev/null || true; _spinner_pid=""; }
run_with_spinner() {
  local msg="$1"; shift
  local cmd=("$@")
  printf "%b[....]%b %s\n" "$C_DIM" "$C_RESET" "$msg"
  (
    while true; do printf "%b⠋%b\r" "$C_DIM" "$C_RESET"; sleep 0.1; printf "%b⠙%b\r" "$C_DIM" "$C_RESET"; sleep 0.1; printf "%b⠹%b\r" "$C_DIM" "$C_RESET"; sleep 0.1; printf "%b⠸%b\r" "$C_DIM" "$C_RESET"; sleep 0.1; printf "%b⠼%b\r" "$C_DIM" "$C_RESET"; sleep 0.1; printf "%b⠴%b\r" "$C_DIM" "$C_RESET"; sleep 0.1; done
  ) & _spinner_pid=$!
  if "${cmd[@]}"; then _stop_spinner; success "$msg"; else _stop_spinner; error "$msg (failed)"; return 1; fi
}

run_with_spinner "Apt update" apt-get update -y
run_with_spinner "Install base packages" apt-get install -y ca-certificates curl gnupg lsb-release rsync iptables iproute2 dnsutils gettext-base unzip iptables-persistent

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

# --- Kolizja portu 80 (hostowy nginx) ---
if systemctl list-unit-files | grep -q '^nginx\.service'; then
  if systemctl is-active --quiet nginx; then
    warn "Wykryto działający nginx na hoście (port 80 może kolidować z Traefikiem)."
    read -r -p "Czy zatrzymać i wyłączyć nginx teraz? (y/N): " DISABLE_NGINX || true
    if [[ ${DISABLE_NGINX:-N} =~ ^[Yy]$ ]]; then
      run_with_spinner "Stop nginx" systemctl stop nginx
      run_with_spinner "Disable nginx" systemctl disable nginx
    else
      warn "Pozostawiono nginx włączony. Traefik może nie otrzymywać ruchu HTTP/80."
    fi
  fi
fi

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

# --- Konfiguracja resolvera systemowego na 10.66.0.1 (opcjonalnie) ---
configure_resolver() {
  local WG_DNS="10.66.0.1"
  if command -v resolvectl >/dev/null 2>&1 && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    info "Wykryto systemd-resolved – ustawiam DNS na ${WG_DNS} (fallback 1.1.1.1)"
    resolvectl dns wg0 ${WG_DNS} 1.1.1.1 || true
    resolvectl domain wg0 "${PRIVATE_SUFFIX}" || true
    resolvectl flush-caches || true
  else
    warn "systemd-resolved nieaktywny – aktualizuję /etc/resolv.conf (zachowuję kopię)"
    if [[ -f /etc/resolv.conf ]]; then cp -n /etc/resolv.conf /etc/resolv.conf.bak.$(date +%s) || true; fi
    cat > /etc/resolv.conf <<RCF
nameserver ${WG_DNS}
nameserver 1.1.1.1
search ${PRIVATE_SUFFIX}
RCF
  fi
}

# Ustaw resolver interaktywnie, chyba że SET_RESOLVER jest już ustawione w env
if [[ -z "${SET_RESOLVER:-}" ]]; then
  read -r -p "Ustawić systemowy resolver DNS na 10.66.0.1? (y/N): " SET_RESOLVER || true
fi
case "${SET_RESOLVER}" in
  1|Y|y|yes|YES)
    configure_resolver || true
    ;;
  *)
    info "Pominięto zmianę resolvera (SET_RESOLVER nieaktywny)"
    ;;
esac

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
step "Konfiguruję Authelię (użytkownik + minimalny configuration.yml)"
# 1) Użytkownik admin
if [[ ! -f "$AUTHELIA_DIR/users_database.yml" ]]; then
  ADMIN_PASS=$(openssl rand -base64 18)
  run_with_spinner "Pull authelia:4.38 (if needed)" bash -lc "docker image inspect authelia/authelia:4.38 >/dev/null 2>&1 || docker pull authelia/authelia:4.38"
  HASH=$(docker run --rm authelia/authelia:4.38 authelia crypto hash generate argon2 --password "$ADMIN_PASS" | tail -1 | sed 's/^.*: //')
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

# 2) Minimalny configuration.yml zgodny z Authelia v4 (bez OIDC, storage local)
NEED_MINIMAL_CFG=0
if [[ ! -f "$AUTHELIA_DIR/configuration.yml" ]]; then
  NEED_MINIMAL_CFG=1
elif [[ "$FORCE_AUTHELIA_MINIMAL" == "1" ]]; then
  NEED_MINIMAL_CFG=1
fi

if [[ "$NEED_MINIMAL_CFG" == "1" ]]; then
  SESS_SECRET=$(openssl rand -base64 48)
  STOR_KEY=$(openssl rand -base64 48)
  OIDC_RSA=""
  OIDC_RSA_ESCAPED=""
  OIDC_WEB_REDIRECT=""
  OIDC_API_REDIRECT=""
  OIDC_API_SECRET=""
  if [[ "$OIDC_ENABLE" == "1" ]]; then
    info "Włączono OIDC: generuję klucz RSA i konfigurację klientów"
    OIDC_RSA=$(openssl genrsa 4096)
    # przygotuj redirecty na podstawie domeny lub portalu VPN
    if [[ -n "$DOMAIN" ]]; then
      OIDC_WEB_REDIRECT="https://${DOMAIN}/oidc/callback"
      OIDC_API_REDIRECT="https://${DOMAIN}/api/core/oidc/callback"
    else
      OIDC_WEB_REDIRECT="http://portal.${PRIVATE_SUFFIX}/oidc/callback"
      OIDC_API_REDIRECT="http://portal.${PRIVATE_SUFFIX}/api/core/oidc/callback"
    fi
    OIDC_API_SECRET=$(openssl rand -hex 32)
  fi
  # backup jeśli istniał
  if [[ -f "$AUTHELIA_DIR/configuration.yml" ]]; then
    cp -v "$AUTHELIA_DIR/configuration.yml" "$AUTHELIA_DIR/configuration.yml.bak.$(date +%s)" || true
  fi
  if [[ "$OIDC_ENABLE" != "1" ]]; then
  cat > "$AUTHELIA_DIR/configuration.yml" <<'YAML'
theme: light

log:
  level: info

server:
  address: 'tcp://0.0.0.0:9091'

authentication_backend:
  file:
    path: /config/users_database.yml

storage:
  encryption_key: REPLACE_STORAGE_KEY
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt

access_control:
  default_policy: one_factor
  rules:
    - domain: ['portal.safe.lan']
      policy: one_factor

session:
  name: 'authelia_session'
  secret: REPLACE_SESSION_SECRET
  domain: 'safe.lan'
  same_site: 'lax'
  expiration: '1h'
  inactivity: '5m'
YAML
  else
  cat > "$AUTHELIA_DIR/configuration.yml" <<YAML
theme: light

log:
  level: info

server:
  address: 'tcp://0.0.0.0:9091'

authentication_backend:
  file:
    path: /config/users_database.yml

storage:
  encryption_key: REPLACE_STORAGE_KEY
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt

access_control:
  default_policy: one_factor
  rules:
    - domain: ['portal.safe.lan']
      policy: one_factor

session:
  name: 'authelia_session'
  secret: REPLACE_SESSION_SECRET
  domain: 'safe.lan'
  same_site: 'lax'
  expiration: '1h'
  inactivity: '5m'

identity_providers:
  oidc:
    # Authelia użyje tego klucza do podpisu tokenów
    issuer_private_key: |
$(echo "$OIDC_RSA" | sed 's/^/      /')
    enforce_pkce: public_clients_only
    clients:
      - id: webapp
        description: Web Frontend (SPA)
        public: true
        redirect_uris:
          - ${OIDC_WEB_REDIRECT}
        scopes:
          - openid
          - profile
          - email
        grant_types:
          - authorization_code
        response_types:
          - code
        token_endpoint_auth_method: none
      - id: core-api
        description: Core API (confidential)
        secret: ${OIDC_API_SECRET}
        redirect_uris:
          - ${OIDC_API_REDIRECT}
        scopes:
          - openid
          - profile
          - email
        grant_types:
          - authorization_code
        response_types:
          - code
        token_endpoint_auth_method: client_secret_post
YAML
  fi
  sed -i "s|REPLACE_STORAGE_KEY|${STOR_KEY//|/\|}|" "$AUTHELIA_DIR/configuration.yml"
  sed -i "s|REPLACE_SESSION_SECRET|${SESS_SECRET//|/\|}|" "$AUTHELIA_DIR/configuration.yml"
  success "Zapisano minimalny Authelia configuration.yml"
else
  info "Pozostawiono istniejący Authelia configuration.yml (ustaw FORCE_AUTHELIA_MINIMAL=1 aby nadpisać)"
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
 - Jeśli hostowy nginx jest uruchomiony, Traefik może nie przejąć portu 80. Rozważ wyłączenie nginx.
EON
