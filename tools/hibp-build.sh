#!/usr/bin/env bash
set -euo pipefail
# Opcjonalny builder cache HIBP (placeholder)
# Tutaj można zbudować lokalny cache range-k hashów HIBP do offline-checku haseł.

usage() {
  echo "Usage: $0 -o OUTPUT_DIR [-l LOG_LEVEL]" >&2
  echo "  -o, --output     Output directory for downloaded prefix files." >&2
  echo "  -l, --log-level  Log level: error, warn, info, debug. Default: info." >&2
  echo "  -h, --help       Show this help." >&2
  exit 1
}

# Defaults
OUTPUT_DIR=""
LOG_LEVEL="info"

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -l|--log-level)
      LOG_LEVEL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "$OUTPUT_DIR" ]]; then
  echo "Output directory is required." >&2
  usage
fi

log_level_num() {
  case "$1" in
    error) echo 0 ;;
    warn)  echo 1 ;;
    info)  echo 2 ;;
    debug) echo 3 ;;
    *)     echo 2 ;;
  esac
}

CURRENT_LOG_LEVEL=$(log_level_num "$LOG_LEVEL")

log() {
  local level="$1"
  shift
  local level_num
  level_num=$(log_level_num "$level")
  if [[ $level_num -le $CURRENT_LOG_LEVEL ]]; then
    printf '[%s] %s\n' "${level^^}" "$*" >&2
  fi
}

command -v curl >/dev/null 2>&1 || {
  log error "curl not found"
  exit 1
}

mkdir -p "$OUTPUT_DIR"

fetch_prefix() {
  local prefix="$1"
  local url="https://api.pwnedpasswords.com/range/$prefix"
  local outfile="$OUTPUT_DIR/$prefix.txt"
  log debug "Fetching $url"
  if ! curl -fsS -A "hibp-build" "$url" -o "$outfile"; then
    log error "Failed to download prefix $prefix"
    exit 1
  fi
}

count=0
if [[ -n ${HIBP_PREFIXES:-} ]]; then
  for prefix in $HIBP_PREFIXES; do
    prefix=${prefix^^}
    fetch_prefix "$prefix"
    count=$((count+1))
  done
else
  for ((i=0; i<=0xFFFFF; i++)); do
    prefix=$(printf '%05X' "$i")
    fetch_prefix "$prefix"
    count=$((count+1))
  done
fi

log info "Successfully fetched $count prefixes into $OUTPUT_DIR"
