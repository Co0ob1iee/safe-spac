# Safe‑Spac Roadmap & Proposals

This document tracks near‑term and mid‑term improvements for the Safe‑Spac installer and stack.

## Spinner & UI
- Time measurements per step (elapsed) and total install time
- Quiet/Verbose modes (env: INSTALLER_VERBOSE=1)
- Section headers (Networking / Docker / Authelia / WireGuard)
- Optional admin password reveal with confirm prompt

## Environment Validation
- Pre‑flight checks: ports 80/443/51820, conflicting services, disk, IPv4/IPv6, rDNS
- Public DNS checks (before), private DNS checks (after)
- Domain A/AAAA verification prior to issuing LE certs

## Error Handling & Self‑Healing
- Retries for apt, docker pull, compose up
- HTTP fallback when LE fails + guidance to re‑run with domain
- --resume (idempotent, skip completed steps)
- Failure report: docker compose ps + tail logs for key services

## Healthchecks (Extended)
- HTTP /health for core‑api and webapp
- Authelia reachability test (authz endpoint: 302/401)
- Safe dry‑run request to wg‑provisioner

## Networking & NAT
- WAN interface detection with selection (eth0/ens3/...)
- IPv6 split/dual‑stack mode (experimental or blocked with guidance)
- Dedicated iptables chain SAFE_SPAC_NAT + clean persistence

## Security
- Harden docker‑socket‑proxy: minimal per‑endpoint permissions
- Admin password rotation script (scripts/rotate-admin.sh)
- Optional fail2ban jail for Traefik auth endpoints
- Permission audit for /opt/safe-spac and /etc/wireguard

## DevOps & Maintenance
- scripts/upgrade.sh (rolling updates + config backup)
- Backup/restore for /opt/safe-spac, /etc/wireguard, users_database.yml
- Dry‑run mode (render only, show planned changes)
- GitHub Actions: lint/format/templating validation

## Logging & Monitoring
- Installer logs to /var/log/safe-spac/install-<timestamp>.log
- Optional observability stack: Promtail/Loki + starter dashboards
- WireGuard metrics exporter (peers/traffic)

## Post‑Install UX
- Summary: admin password path/rotation, backup paths, start/stop commands, URLs
- WireGuard profile QR code (ASCII)
- scripts/add-user.sh (guided user creation)

## Documentation
- Architecture diagram (Mermaid + PNG)
- Troubleshooting for LE/iptables/kernel modules
- Security model (Docker API access, secret storage)
