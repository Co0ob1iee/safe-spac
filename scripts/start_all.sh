#!/usr/bin/env bash
set -euo pipefail
LOG=/var/log/safe-spac-restart.log
{
  date
  echo "[INFO] Bringing up compose stack..."
  cd /opt/safe-spac/server
  docker compose up -d
} >>"$LOG" 2>&1
