#!/usr/bin/env bash
set -euo pipefail

REPO_URL=${REPO_URL:-"https://github.com/Co0ob1iee/safe-spac.git"}
BRANCH=${BRANCH:-main}
TARGET_DIR=${TARGET_DIR:-/root/safe-spac}

if [[ ${EUID} -ne 0 ]]; then
  echo "[ERR] Uruchom jako root (sudo)" >&2
  exit 1
fi

apt-get update -y
apt-get install -y git ca-certificates curl

rm -rf "$TARGET_DIR.tmp" && mkdir -p "$TARGET_DIR.tmp"
cd "$TARGET_DIR.tmp"

echo "[INFO] Klonuję repozytorium: $REPO_URL (#$BRANCH)"
GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "$BRANCH" "$REPO_URL" repo
mv repo "$TARGET_DIR"
cd "$TARGET_DIR"

# ensure executables
chmod +x "$TARGET_DIR/install.sh" 2>/dev/null || true
chmod +x "$TARGET_DIR"/scripts/*.sh 2>/dev/null || true

exec bash "$TARGET_DIR/install.sh"
