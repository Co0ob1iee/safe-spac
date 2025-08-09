# safe-spac

## Szybka instalacja (VPS Debian 12)

- Bez domeny (HTTP):
```bash
curl -fsSL https://raw.githubusercontent.com/Co0ob1iee/safe-spac/main/quick-install.sh | sudo bash
```

- Z domeną (HTTPS + Let's Encrypt):
```bash
curl -fsSL https://raw.githubusercontent.com/Co0ob1iee/safe-spac/main/quick-install.sh | sudo HAS_DOMAIN=Y bash
```

- Przykład non-interactive (IP + full-tunnel):
```bash
curl -fsSL https://raw.githubusercontent.com/Co0ob1iee/safe-spac/main/quick-install.sh | \
  sudo PUBLIC_IP=203.0.113.10 FULL_TUNNEL=Y bash
```

Zmiennie środowiskowe wspierane przez instalator:
- `PUBLIC_IP` – IP serwera (gdy brak domeny lub tryb non-interactive)
- `FULL_TUNNEL=Y|N` – włącza NAT oraz AllowedIPs=0.0.0.0/0
- `WG_SUBNET`, `WG_ADDR`, `PRIVATE_SUFFIX` – nadpisanie domyślnych wartości

1) Struktura projektu (drzewo + opis)

safe-spac/
├─ install.sh                         # Główny instalator na VPS (root). Stawia wszystko, generuje WG i admina.
├─ README.md                          # Skrót uruchomienia (możesz wkleić ten dokument)
│
├─ scripts/
│  ├─ start_all.sh                    # Podnosi cały stack Docker Compose (używane też przez cron @reboot)
│  └─ install_cron.sh                 # Dodaje @reboot do crona (start_all.sh)
│
├─ dnsmasq/
│  └─ dnsmasq.conf.tmpl               # Szablon prywatnego DNS: portal.safe.lan, service.teamspeak, service.git
│
├─ server/
│  ├─ docker-compose.yml.tmpl         # Szablon Compose z usługami i Traefikiem (public/private routing)
│  │
│  ├─ authelia/
│  │  ├─ configuration.yml            # Renderowany przez instalator (minimalny plik backend)
│  │  └─ users_database.yml           # Renderowany przez instalator (admin@example.com + losowe hasło)
│  │
│  ├─ webapp/
│  │  ├─ Dockerfile                   # Serwuje publiczny front (/, /register, /invite) – prosty HTTP
│  │  ├─ package.json                 # Placeholder dependency (Node 20)
│  │  └─ package-lock.json            # (placeholder)
│  │
│  ├─ core-api/
│  │  ├─ Dockerfile                   # Go 1.22, buduje binarkę coreapi
│  │  ├─ go.mod                       # zależności: fiber, x/crypto, docker client
│  │  └─ cmd/coreapi/main.go          # Rejestracja (wnioski), captcha, zaproszenia, audit, health, proxy do prov
│  │
│  ├─ wg-provisioner/
│  │  ├─ Dockerfile                   # Go 1.22, wydaje realny .conf bazując na /etc/wireguard/server.pub + PUBLIC_IP
│  │  ├─ go.mod                       # zależność: fiber
│  │  └─ cmd/provisioner/main.go
│  │
│  ├─ teamspeak/
│  │  └─ install_ts6.sh               # Pobiera TS6 z oficjalnego URL i odpala kontener na tych plikach
│  │
│  ├─ gitea/                          # Dane Gitea (tworzone przez kontener)
│  └─ data/                           # Dane core-api (pending.json, invites.json, audit.log)
│
├─ client/
│  ├─ windows/
│  │  ├─ Installer.iss                # Inno Setup – instalator klienta Windows
│  │  └─ download.ps1                 # Pobiera i instaluje WireGuard + (opcjonalnie) TS6
│  │
│  └─ desktop/
│     ├─ package.json                 # Electron + electron-builder (AppImage)
│     └─ src/main.js                  # Minimalny launcher UI (info dla usera)
│
├─ tools/
│  ├─ wg-client-sample.conf           # Przykładowy klient WG (do ręcznych testów)
│  └─ hibp-build.sh                   # Opcjonalny builder cache HIBP (jeśli zechcesz dodać sprawdzanie haseł)
│
└─ .github/workflows/
   ├─ windows-installer.yml           # GH Actions – buduje .exe (Inno Setup)
   └─ linux-appimage.yml              # GH Actions – buduje .AppImage (Electron)

## Najważniejsze ścieżki danych po instalacji

- WireGuard serwer: `/etc/wireguard/`
  - server.key, server.pub, admin.key, admin.pub, wg0.conf
- Admin klient WG: `/opt/safe-spac/tools/admin-wg.conf`
- dnsmasq (konf renderowany): `/opt/safe-spac/dnsmasq/dnsmasq.conf`
- Authelia (renderowane): `/opt/safe-spac/authelia/configuration.yml`, `/opt/safe-spac/authelia/users_database.yml`
- Core API dane: `/opt/safe-spac/server/data/`
- Log autostartu: `/var/log/safe-spac-restart.log` (z crona)

## 2) Zależności (co trzeba mieć)

VPS (Debian 12):

- docker-ce, docker-compose-plugin (instaluje instalator)
- wireguard-tools (wg, wg-quick)
- iptables, iproute2, dnsutils, gettext-base (instalator używa)
- curl, gnupg, lsb-release, rsync (instalator używa)

Kontenery (pobierane automatycznie):

- traefik:2.11
- ghcr.io/jpillora/dnsmasq:latest
- authelia/authelia:4.38 (do generacji hasha; sam kontener Authelii możesz dodać później wg potrzeb)
- gitea/gitea:1.22
- debian:stable-slim (placeholder TS6)
- Obrazy budowane lokalnie: core-api, wg-provisioner, webapp

Windows client build:

- Inno Setup (ISCC), PowerShell (w systemie)
- (Opcjonalnie) GitHub Actions runner windows-latest

Linux AppImage build:

- Node 20, electron-builder
- (Opcjonalnie) GH Actions ubuntu-latest

## 3) Jak to działa – architektura w skrócie

Publicznie (po IP):

- `http://<PUBLIC_IP>` → Traefik wystawia tylko:
  - WebApp: `/`, `/register`, `/invite/*`
  - Core-API: `/api/core/registration/*`, `/api/core/captcha/*`

Prywatnie (po VPN + prywatny DNS):

- `http://portal.safe.lan` → WebApp (całe `/app`, `/admin`, reszta API)
- `service.teamspeak` → TS6 (jak zainstalujesz binarki oficjalne)
- `service.git` → Gitea

WireGuard (wg0):

- Serwer: `10.66.0.1/24`, port `51820/udp`.
- Klienci dostają „push DNS” przez wpis w `.conf`: `DNS = 10.66.0.1` (to nasz dnsmasq).
- dnsmasq rozwiązuje wewnętrzne nazwy na IP `10.66.0.1`, więc wszystko poza logowaniem jest „widoczne” wyłącznie po VPN.

Traefik:

- Dwa zestawy routerów:
  - public (po IP, bez whitelista) → publiczne ścieżki
  - vpn-only (host `portal.safe.lan` + middleware ipwhitelist na `10.66.0.0/24`) → cała reszta

Authelia (file backend):

- Działa tu jako prosty user store (docelowo możesz dobudować pełny SSO/OIDC).
- Instalator tworzy `admin@example.com` z losowym hasłem i dodaje do `groups: [admins, users]`.

Core API:

- `/api/core/captcha/*` – prosta CAPTCHA (stub HMAC).
- `/api/core/registration/*` – wnioski, zapis do `pending.json`.
- `/api/core/admin/*` – akceptacja wniosku generuje wpis w `users_database.yml` + restart Authelii przez Docker API.
- `/api/core/invite/*` – linki zaproszeń (tokeny + termin ważności).
- `/api/core/vpn/issue` – proxy do wg-provisioner (wydanie `.conf`).

WG Provisioner:

- Czyta `/etc/wireguard/server.pub` w host-mount i `PUBLIC_IP` z env.
- Zwraca konfigurację klienta (domyślny split: `AllowedIPs = 10.66.0.0/24`).

TeamSpeak 6:

- Nie trzymamy binarek (licencja). Skrypt `install_ts6.sh` pobiera oficjalny `tar.gz`, mapuje do kontenera i startuje usługę.

## 4) Odtworzenie projektu – krok po kroku

### A. Uruchomienie na VPS (czysty Debian 12)

```bash
# wgraj paczkę (albo sklonuj repo)
scp safe-spac-full-fat-all.zip root@<IP_VPS>:/root/
ssh root@<IP_VPS>
apt update && apt install -y unzip
unzip safe-spac-full-fat-all.zip -d /root/safe-spac
cd /root/safe-spac

# jedyny wymagany parametr: PUBLIC_IP (Twoje IP publiczne)
sudo PUBLIC_IP=<TWOJE_PUBLICZNE_IP> ./install.sh
```

Na końcu instalator pokaże:

- login: `admin@example.com`
- hasło tymczasowe admina (zapisz!)
- ścieżkę do `/opt/safe-spac/tools/admin-wg.conf`

Po instalacji:

- Importuj `admin-wg.conf` w kliencie WireGuard, połącz.
- Wejdź w `http://portal.safe.lan` (działa tylko z tunelu).
- Publiczny front (logowanie/rejestracja): `http://<PUBLIC_IP>`.

### B. TeamSpeak 6 (serwer) – oficjalne binarki

```bash
export TS6_URL="https://<OFICJALNY_LINK_DO_TS6_TAR_GZ>"
sudo /opt/safe-spac/server/teamspeak/install_ts6.sh
# Po VPN łącz się: service.teamspeak
```

### C. Klient Windows – instalator

Lokalnie (Windows + Inno Setup) lub przez GitHub Actions.

- Lokalnie:
  - Zainstaluj Inno Setup.
  - `ISCC.exe client/windows/Installer.iss`
  - Połóż `admin-wg.conf` obok `SafeSpac-Setup.exe` → podczas instalacji zostanie zaimportowany.
- GH Actions: workflow `.github/workflows/windows-installer.yml`.

### D. Klient Linux – AppImage

- GH Actions: `.github/workflows/linux-appimage.yml` (node 20, electron-builder).
- Lokalnie: w `client/desktop` → `npm ci && npm run dist:linux` (wymaga linux build toolchain).

## 5) Porty / domeny / DNS

- Publicznie: `:80` (Traefik). Brak TLS (bo brak domeny); można dodać Let’s Encrypt po wprowadzeniu domen.
- WireGuard: `51820/udp` (na hoście).
- DNS wewnętrzny: dnsmasq na hoście (host-mode), adres: `10.66.0.1`.
- Prywatne hosty:
  - `portal.safe.lan` → `10.66.0.1`
  - `service.teamspeak` → `10.66.0.1`
  - `service.git` → `10.66.0.1`

## 6) Zmiana ustawień i customizacja

- Podsieć VPN: domyślnie `10.66.0.0/24`.
  - Zmień w `install.sh` (konstanta `WG_SUBNET`) i w `server/docker-compose.yml.tmpl` (ipwhitelist).
  - Podmień `Address` w `/etc/wireguard/wg0.conf` i w profilach klientów.
- Prywatny sufiks DNS: domyślnie `safe.lan`.
  - Zmień w `install.sh` (`PRIVATE_SUFFIX`) i zrenderuj ponownie `dnsmasq.conf`.
- Routing klientów:
  - Provisioner domyślnie zwraca `AllowedIPs = 10.66.0.0/24` (split-tunnel do zasobów wewnętrznych).
  - Zmień w `wg-provisioner/cmd/provisioner/main.go` → np. `0.0.0.0/0` (full-tunnel), albo dwie opcje.
- TLS/LE:
  - Dodaj entrypoint `websecure :443`, `certresolver` i prawdziwą domenę dla publicznych routerów.

## 7) Utrzymanie / upgrade

- Start/stop:

```bash
cd /opt/safe-spac/server
docker compose up -d
docker compose down
```

- Autostart:

```bash
/opt/safe-spac/scripts/install_cron.sh
crontab -l
```

- Logi (przykład):

```bash
docker compose logs -n 200 core-api
docker compose ps
```

- Zmiana hasła admina (Authelia):

```bash
NEWPASS=NoweSilneHaslo123
HASH=$(docker run --rm authelia/authelia:4.38 authelia crypto hash generate argon2 --password "$NEWPASS" | tail -1 | sed 's/^.*: //')
nano /opt/safe-spac/authelia/users_database.yml  # podmień "password:"
docker compose restart authelia
```

- Backup:
  - `/etc/wireguard/` (klucze + wg0.conf)
  - `/opt/safe-spac/authelia/`
  - `/opt/safe-spac/server/data/`
  - `/opt/safe-spac/server/gitea/` (cała zawartość)

## 8) Typowe problemy i szybkie fixy

- Brak sudo: unable to resolve host  
  Dopisz hostname do `/etc/hosts`:

```bash
echo "127.0.0.1 localhost $(hostname)" >> /etc/hosts
```

  (Instalator to robi, ale jeśli przegapi – zrób ręcznie.)

- `wg-quick@wg0` nie startuje  
  Sprawdź `journalctl -u wg-quick@wg0 -e`. Najczęściej błąd w `wg0.conf`.  
  Upewnij się, że `Address = 10.66.0.1/24` i `PrivateKey` niepusty.

- Brak rozwiązywania `portal.safe.lan`  
  Klient musi mieć `DNS = 10.66.0.1` w profilu WG. Zaimportuj `admin-wg.conf` ponownie.

- Publiczny front nie działa  
  Sprawdź `docker compose logs traefik`. Upewnij się, że port 80 nie jest zajęty (np. przez apache).

- TS6 nie wstaje (po `install_ts6.sh`)  
  Zależy od struktury archiwum TS6. Zajrzyj do `/opt/safe-spac/ts6/<DIR>/` i sprawdź nazwę binarki (komenda w override uruchamia tsserver/start.sh – dopasuj).

## 9) Minimalny przebieg „od zera do gotowe”

- Wgraj i odpal `install.sh` z `PUBLIC_IP`.
- Zapisz wyświetlone hasło admina i zaimportuj `/opt/safe-spac/tools/admin-wg.conf`.
- Połącz WG → wejdź: `http://portal.safe.lan`.
- Publicznie: `http://<PUBLIC_IP>` → wnioski rejestracyjne / zaproszenia działają bez VPN.
- (Opcjonalnie) odpal TS6 skryptem z oficjalnym URL.
- (Opcjonalnie) zbuduj klient Windows/AppImage przez GH Actions.
