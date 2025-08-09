#!/usr/bin/env bash
set -euo pipefail
# TeamSpeak 6 installer (placeholder)
# Requires TS6_URL env with official tar.gz link

INSTALL_ROOT=${INSTALL_ROOT:-/opt/safe-spac}
TS_DIR="$INSTALL_ROOT/ts6"

if [[ -z "${TS6_URL:-}" ]]; then
  echo "[ERR] Set TS6_URL to official TS6 tar.gz URL" >&2
  exit 1
fi

mkdir -p "$TS_DIR"
cd "$TS_DIR"

echo "[INFO] Downloading TS6 from $TS6_URL"
curl -fsSL "$TS6_URL" -o ts6.tar.gz
mkdir -p extracted
 tar -xzf ts6.tar.gz -C extracted --strip-components=1 || true

# Compose override to map TS6 files and run server
cat > "$INSTALL_ROOT/server/ts6.override.yml" <<YML
version: '3.9'
services:
  teamspeak6:
    image: debian:stable-slim
    volumes:
      - $TS_DIR/extracted:/opt/ts6
    working_dir: /opt/ts6
    command: ["/opt/ts6/tsserver/start.sh"]
    network_mode: host
YML

echo "[INFO] Starting TeamSpeak 6 via compose override"
cd "$INSTALL_ROOT/server"
docker compose -f docker-compose.yml -f ts6.override.yml up -d

echo "[OK] TS6 started (host network). Access inside VPN at service.teamspeak"
