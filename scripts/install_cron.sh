#!/usr/bin/env bash
set -euo pipefail
# Install @reboot entry to start docker stack
CRON_LINE='@reboot /opt/safe-spac/scripts/start_all.sh'
( crontab -l 2>/dev/null | grep -v "/opt/safe-spac/scripts/start_all.sh" || true; echo "$CRON_LINE" ) | crontab -
echo "[OK] Cron @reboot installed"
