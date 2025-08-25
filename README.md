<div align="center">

# 🛰️ Safe‑Spac

A production‑ready, fully automated, self‑hosted VPN platform built on WireGuard, Traefik, Authelia, and dnsmasq — with Core API, WG Provisioner, and optional Gitea/TeamSpeak services. Designed for Debian 12 VPS and zero‑to‑prod in minutes.

[![Made for Debian 12](https://img.shields.io/badge/Debian-12-red?logo=debian)](https://www.debian.org/releases/bookworm/) 
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/) 
[![WireGuard](https://img.shields.io/badge/WireGuard-Enabled-88171A?logo=wireguard&logoColor=white)](https://www.wireguard.com/) 
[![License](https://img.shields.io/badge/License-TBD-gray.svg)](#license)

</div>

---

## 🚀 Quick Install (Debian 12 VPS)

- No domain (HTTP):

```bash
curl -fsSL https://raw.githubusercontent.com/Co0ob1iee/safe-spac/main/quick-install.sh | sudo bash
```

- With domain (HTTPS + Let’s Encrypt):

```bash
curl -fsSL https://raw.githubusercontent.com/Co0ob1iee/safe-spac/main/quick-install.sh | sudo HAS_DOMAIN=Y DOMAIN=your-domain.com ACME_EMAIL=your-email@example.com bash
```

- Non‑interactive example (force IP + full‑tunnel):

```bash
curl -fsSL https://raw.githubusercontent.com/Co0ob1iee/safe-spac/main/quick-install.sh | \
  sudo PUBLIC_IP=203.0.113.10 FULL_TUNNEL=Y bash
```

Supported environment variables:
- `HAS_DOMAIN=Y|N` – whether server has a domain (for non‑interactive runs)
- `DOMAIN` – public domain name (required when HAS_DOMAIN=Y)
- `ACME_EMAIL` – email for Let's Encrypt (required when HAS_DOMAIN=Y)
- `PUBLIC_IP` – server IP (when no domain or for non‑interactive runs)
- `FULL_TUNNEL=Y|N` – enable NAT and AllowedIPs=0.0.0.0/0
- `WG_SUBNET`, `WG_ADDR`, `PRIVATE_SUFFIX` – override defaults

---

## ✨ Highlights

- 🔧 One‑command installer: Docker CE + Compose, WireGuard, dnsmasq, Traefik, Authelia
- 🔐 Authelia admin auto‑provisioning with secure Argon2id hash
- 🧠 Core‑API with persistent `pending.json` and `invites.json`
- ♻️ Authelia hot‑reload via Docker API (through hardened docker‑socket‑proxy)
- 🌐 Split‑tunnel by default; optional full‑tunnel (NAT) with iptables‑persistent
- 🧭 Private DNS (`safe.lan`) via dnsmasq; internal routes only accessible over VPN
- 🧱 Traefik separation: public endpoints vs VPN‑only (IP whitelist)
- 🔌 Extensible services: Gitea, TeamSpeak 6, Web front

---

## 🧩 Architecture Overview

```
Client ↔ WireGuard (wg0)
              │
          dnsmasq (host net, 10.66.0.1)
              │
         Traefik (80[/443 when domain])
          ├── WebApp (public + vpn-only)
          ├── Core API (public + admin over VPN)
          ├── Gitea (vpn-only)
          └── TS6 (vpn-only)

Authelia (file backend: /opt/safe-spac/authelia)
Core data (/opt/safe-spac/server/data): pending.json, invites.json
WG Provisioner (reads /etc/wireguard/server.pub, issues client .conf)
```

Key networks and defaults:
- WG subnet: `10.66.0.0/24`
- Server WG address: `10.66.0.1/24`
- Private DNS suffix: `safe.lan`
- Public entrypoint: `:80` (+`:443` when domain is configured)

---

## 🛠️ What the installer does

- Installs Docker CE, Compose plugin, `wireguard-tools`, and common utilities
- Generates WireGuard keys and renders `/etc/wireguard/wg0.conf`
- Enables and starts `wg-quick@wg0`
- Renders dnsmasq config and starts the stack via Docker Compose
- Creates Authelia admin (`admin@example.com`) with a random secure password and writes `/opt/safe-spac/authelia/users_database.yml`
- Sets up Traefik routers for public and VPN‑only traffic
- Optionally enables full‑tunnel NAT with idempotent iptables rules and `iptables-persistent`
- Adds `@reboot` cron to auto‑start the stack

---

## 🔑 Regenerating Authelia admin password

The installer creates `admin@example.com` with a random password and stores its Argon2id hash in `server/authelia/users_database.yml`.
To change this password later, generate a new hash and replace the value in that file:

```bash
docker run --rm authelia/authelia:4.38 \
  authelia crypto hash generate argon2 --password "NEW_PASSWORD"
```

Copy the produced `$argon2id$...` string into `server/authelia/users_database.yml` under the `password` field for `admin@example.com` and restart the Authelia container.

---

## 📦 Project Layout

```
safe-spac/
├─ install.sh                  # Main installer (root) – end‑to‑end provisioning
├─ quick-install.sh            # Bootstrapper (clone + run installer)
├─ server/
│  ├─ docker-compose.yml.tmpl  # Compose template (Traefik, dnsmasq, webapp, core-api, wg-provisioner, gitea, authelia)
│  ├─ authelia/
│  │  ├─ configuration.yml
│  │  └─ users_database.yml
│  ├─ core-api/
│  │  ├─ Dockerfile
│  │  ├─ go.mod
│  │  └─ cmd/coreapi/main.go
│  ├─ wg-provisioner/
│  │  ├─ Dockerfile
│  │  ├─ go.mod
│  │  └─ cmd/provisioner/main.go
│  ├─ webapp/
│  │  ├─ Dockerfile
│  │  └─ public/index.html
│  └─ teamspeak/install_ts6.sh
├─ dnsmasq/dnsmasq.conf.tmpl   # Private DNS: portal.safe.lan, service.teamspeak, service.git
├─ scripts/{start_all.sh, install_cron.sh}
└─ tools/{wg-client-sample.conf}
```

---

## 🔐 Security & Hardening

- Docker API access is proxied via `tecnativa/docker-socket-proxy` with restricted capabilities (no raw socket mounts in app containers)
- VPN‑only routes are enforced with Traefik ipWhitelist middleware for `10.66.0.0/24`
- Authelia uses file backend for simplicity; can be upgraded to full OIDC SSO later
- Secrets and keys are generated on the host; ensure backups of `/etc/wireguard/` and `/opt/safe-spac/authelia/`

Recommended next steps:
- Add internal‑only Docker network between `core-api` and the proxy
- Optionally enforce SSO (JWT) on Admin API endpoints
- Consider read‑only/more granular permissions on the proxy (only what’s needed to restart Authelia)

---

## 🌍 Split vs Full Tunnel

- Split‑tunnel (default): `AllowedIPs=10.66.0.0/24` – only internal resources go through the VPN
- Full‑tunnel (optional): `AllowedIPs=0.0.0.0/0` – all traffic via VPS
  - Installer enables `net.ipv4.ip_forward=1`
  - Adds idempotent iptables MASQUERADE and FORWARD rules
  - Persists rules with `netfilter-persistent`

Enable full‑tunnel during install or set env:

```bash
FULL_TUNNEL=Y
```

---

## 🧪 Health & Admin flows

- Health: `GET /api/core/health`
- Registration: `POST /api/core/registration/submit` → saved to `pending.json`
- Invites: `POST /api/core/invite/create` → token + TTL saved to `invites.json`
- Admin accept: `POST /api/core/admin/accept` → user added to `users_database.yml` → Authelia container restart via Docker API
- Issue client config: `POST /api/core/vpn/issue` → proxy to WG Provisioner

Note: Admin endpoints are routed as VPN‑only via Traefik and private DNS.

---

## 🧰 Requirements

- Debian 12 VPS with root access
- Open ports: `80/tcp` (and `443/tcp` when using a domain), `51820/udp`
- A domain (optional) with A record to your VPS IP (for HTTPS / Let’s Encrypt)

---

## 🧯 Troubleshooting

- Let’s Encrypt doesn’t issue certs
  - Ensure domain A record points to your VPS
  - Ports `80` and `443` are reachable from the Internet
- VPN private DNS not resolving
  - Ensure you’re connected to WireGuard (clients get `DNS = 10.66.0.1`)
  - Check `dnsmasq` logs and that its container is running
- No Internet on full‑tunnel
  - Verify `net.ipv4.ip_forward=1` and NAT rules are present
  - Run `netfilter-persistent save` again if needed

---

## 🗺️ Roadmap

- Admin API split with enforced SSO (Authelia OIDC/JWT)
- Internal Docker network hardening for API ↔ proxy
- Extended observability (Prometheus + Loki + Grafana)
- Automated client builders (Windows/Electron) via GitHub Actions

---

## 📜 License

TBD. Until a license is added, treat this repository as “all rights reserved”.

---

## 🙌 Credits

- WireGuard, Traefik, Authelia, dnsmasq, Gitea, Electron, Inno Setup
- Community best practices and patterns from modern self‑hosting stacks
