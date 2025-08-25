#!/usr/bin/env bash
set -euo pipefail

# Użyj lokalnego pliku install.sh zamiast pobierać z GitHub
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd -P)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"

if [[ ${EUID} -ne 0 ]]; then
  echo "[ERR] Uruchom jako root (sudo)" >&2
  exit 1
fi

# Sprawdź czy lokalny plik install.sh istnieje
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
  echo "[ERR] Nie znaleziono lokalnego pliku install.sh w $SCRIPT_DIR" >&2
  echo "[INFO] Pobieram z GitHub jako fallback..." >&2
  
  # Fallback: pobierz z GitHub
  REPO_URL=${REPO_URL:-"https://github.com/Co0ob1iee/safe-spac.git"}
  BRANCH=${BRANCH:-main}
  TARGET_DIR=${TARGET_DIR:-/root/safe-spac}
  
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
else
  echo "[INFO] Używam lokalnego pliku install.sh z $SCRIPT_DIR"
  echo "[INFO] Uruchamiam: $INSTALL_SCRIPT"
  
  # Uruchom lokalny skrypt z przekazanymi zmiennymi środowiskowymi
  exec bash "$INSTALL_SCRIPT"
fi
