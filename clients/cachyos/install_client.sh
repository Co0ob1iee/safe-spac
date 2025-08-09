#!/usr/bin/env bash
set -euo pipefail

# Safe‑Spac – instalacja klienta WireGuard na CachyOS (Arch)
# Użycie:
#   ./install_client.sh --config ./admin-wg.conf [--nm]
#   lub bez flag – spróbuje użyć ./admin-wg.conf z bieżącego katalogu.
#
# Opcje:
#   --config <plik>  Ścieżka do pliku konfiguracyjnego WireGuard (np. admin-wg.conf)
#   --nm             Zamiast /etc/wireguard użyj NetworkManager (nmcli import)
#
# Wymagania: pacman, sudo, internet.

CONFIG_SRC=""
USE_NM=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_SRC="${2:-}"; shift 2;;
    --nm)
      USE_NM=1; shift;;
    *)
      echo "Nieznana opcja: $1" >&2; exit 2;;
  esac
done

if [[ -z "${CONFIG_SRC}" ]]; then
  if [[ -f ./admin-wg.conf ]]; then
    CONFIG_SRC=./admin-wg.conf
  else
    echo "Brak --config i nie znaleziono ./admin-wg.conf" >&2
    exit 1
  fi
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "Ten skrypt jest przeznaczony dla systemów Arch/CachyOS (wymaga pacman)." >&2
  exit 1
fi

# Pakiety: wireguard-tools (wg/wg-quick), openresolv (DNS hook dla wg-quick), opcjonalnie NetworkManager
PKGS=(wireguard-tools openresolv)
if [[ "$USE_NM" -eq 1 ]]; then
  PKGS+=(networkmanager nm-connection-editor)
fi

sudo pacman -Sy --needed --noconfirm "${PKGS[@]}"

# Import konfiguracji
if [[ "$USE_NM" -eq 1 ]]; then
  # Import do NetworkManager jako połączenie "safe-spac"
  # Uwaga: nmcli wspiera import od pliku wg (INI)
  set +e
  EXISTING_ID=$(nmcli -t -f NAME con show | grep -Fx "safe-spac" || true)
  set -e
  if [[ -n "$EXISTING_ID" ]]; then
    sudo nmcli con delete "safe-spac" || true
  fi
  sudo nmcli connection import type wireguard file "$CONFIG_SRC"
  # Zmień nazwę na spójną (jeśli import zastosował inną)
  set +e
  IMPORTED=$(nmcli -t -f NAME,TYPE con show | awk -F: '$2=="wireguard"{print $1; exit}')
  set -e
  if [[ -n "${IMPORTED:-}" && "${IMPORTED}" != "safe-spac" ]]; then
    sudo nmcli con modify "$IMPORTED" connection.id "safe-spac"
  fi
  echo "Uruchamiam połączenie WireGuard przez NetworkManager: safe-spac"
  sudo nmcli con up safe-spac
else
  # Instalacja do /etc/wireguard/safe-spac.conf
  TMP=$(mktemp)
  install -m 600 "$CONFIG_SRC" "$TMP"
  sudo install -m 600 -o root -g root "$TMP" /etc/wireguard/safe-spac.conf
  rm -f "$TMP"
  # Włącz i uruchom wg-quick
  sudo systemctl enable --now wg-quick@safe-spac.service
fi

# Testy podstawowe
sleep 1
set +e
WG_OK=1
sudo wg show safe-spac >/dev/null 2>&1 || WG_OK=0

DNS_OK=1
getent hosts portal.safe.lan >/dev/null 2>&1 || DNS_OK=0

HTTP_OK=1
curl -skI https://wp.pl >/dev/null 2>&1 || HTTP_OK=0
set -e

echo ""
if [[ "$WG_OK" -eq 1 ]]; then echo "[OK] WireGuard interfejs działa (safe-spac)"; else echo "[WARN] WireGuard nie potwierdził interfejsu (safe-spac)"; fi
if [[ "$DNS_OK" -eq 1 ]]; then echo "[OK] DNS przez VPN działa (portal.safe.lan)"; else echo "[WARN] DNS nie działa (portal.safe.lan)"; fi
if [[ "$HTTP_OK" -eq 1 ]]; then echo "[OK] Wyjście do internetu przez VPN działa (https://wp.pl)"; else echo "[WARN] Brak potwierdzenia HTTP(S)"; fi

echo ""
echo "Zakończono instalację klienta."
