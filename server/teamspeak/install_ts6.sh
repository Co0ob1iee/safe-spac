#!/usr/bin/env bash
set -euo pipefail
# TeamSpeak 6 installer
#
# Usage:
#   TS6_URL=<official tar.gz> TS6_SHA256=<sum> ./install_ts6.sh
#
# Optional env vars:
#   TS6_PORT_VOICE - UDP voice port exposed on host (default 9987)
#   TS6_PORT_QUERY - TCP query port exposed on host (default 10011)
#   TS6_PORT_FILE  - TCP file port exposed on host (default 30033)
#   TS6_MEM_LIMIT  - container memory limit (default 512m)
#   TS6_CPUS       - container CPU cores (default 1.0)
#   TS6_LICENSE    - value for TS6_LICENSE env passed to container (default accept)
# TeamSpeak 6 installer (placeholder)
# Requires TS6_URL env with official tar.gz link

INSTALL_ROOT=${INSTALL_ROOT:-/opt/safe-spac}
TS_DIR="$INSTALL_ROOT/ts6"

TS6_PORT_VOICE=${TS6_PORT_VOICE:-9987}
TS6_PORT_QUERY=${TS6_PORT_QUERY:-10011}
TS6_PORT_FILE=${TS6_PORT_FILE:-30033}
TS6_MEM_LIMIT=${TS6_MEM_LIMIT:-512m}
TS6_CPUS=${TS6_CPUS:-1.0}
TS6_LICENSE=${TS6_LICENSE:-accept}

if [[ -z "${TS6_URL:-}" ]]; then
  echo "[ERR] Set TS6_URL to official TS6 tar.gz URL" >&2
  exit 1
fi

mkdir -p "$TS_DIR"
cd "$TS_DIR"

echo "[INFO] Downloading TS6 from $TS6_URL"
curl -fsSL "$TS6_URL" -o ts6.tar.gz
if [[ -n "${TS6_SHA256:-}" ]]; then
  echo "$TS6_SHA256  ts6.tar.gz" | sha256sum -c - || { echo "[ERR] SHA256 mismatch" >&2; exit 1; }
else
  echo "[WARN] TS6_SHA256 not set; skipping checksum verification" >&2
fi
mkdir -p extracted data
tar -xzf ts6.tar.gz -C extracted --strip-components=1 || true

# Compose override to map TS6 files and run server
cat > "$INSTALL_ROOT/server/ts6.override.yml" <<YML
version: '3.9'
services:
  teamspeak6:
    image: debian:stable-slim
    environment:
      TS6_LICENSE: $TS6_LICENSE
    ports:
      - "$TS6_PORT_VOICE:9987/udp"
      - "$TS6_PORT_QUERY:10011/tcp"
      - "$TS6_PORT_FILE:30033/tcp"
    volumes:
      - $TS_DIR/extracted:/opt/ts6
      - $TS_DIR/data:/var/ts6-data
    working_dir: /opt/ts6
    command: ["/opt/ts6/tsserver/start.sh"]
    restart: unless-stopped
    mem_limit: $TS6_MEM_LIMIT
    cpus: $TS6_CPUS
YML

echo "[INFO] Starting TeamSpeak 6 via compose override"
cd "$INSTALL_ROOT/server"
docker compose -f docker-compose.yml -f ts6.override.yml up -d

echo "[OK] TS6 started. Access via mapped ports"
