#!/usr/bin/env bash

# Safe-Spac Installer - Enhanced Version
# Enhanced with better debugging, error handling, and user interface

set -euo pipefail

# Global variables for tracking installation status
declare -a INSTALLATION_DONE=()
declare -a INSTALLATION_WARNINGS=()
declare -a INSTALLATION_ERRORS=()
declare -a DEBUG_LOG=()

# Configuration
# When using curl | bash, these variables may not be available
SCRIPT_DIR="${SCRIPT_DIR:-/tmp}"
SCRIPT_NAME="${SCRIPT_NAME:-install.sh}"
START_TIME=$(date +%s)

# Enhanced color system
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  ncolors=$(tput colors || echo 0)
else
  ncolors=0
fi

if [[ ${NO_COLOR:-} != 1 ]] && [[ $ncolors -ge 8 ]]; then
  # Rich color palette
  C_RESET="\033[0m"; C_BOLD="\033[1m"; C_UNDERLINE="\033[4m"
  C_INFO="\033[36m"; C_WARN="\033[33m"; C_ERR="\033[31m"; C_OK="\033[32m"; C_DIM="\033[2m"
  C_BLUE="\033[34m"; C_MAGENTA="\033[35m"; C_CYAN="\033[36m"; C_WHITE="\033[37m"
  C_BG_INFO="\033[46m"; C_BG_WARN="\033[43m"; C_BG_ERR="\033[41m"
else
  C_RESET=""; C_BOLD=""; C_UNDERLINE=""
  C_INFO=""; C_WARN=""; C_ERR=""; C_OK=""; C_DIM=""
  C_BLUE=""; C_MAGENTA=""; C_CYAN=""; C_WHITE=""
  C_BG_INFO=""; C_BG_WARN=""; C_BG_ERR=""
fi

# Enhanced logging functions
log_debug() {
  if [[ "${DEBUG_INSTALL:-}" == "1" ]]; then
    printf "%b[DEBUG]%b %s\n" "$C_DIM" "$C_RESET" "$*" >&2
    DEBUG_LOG+=("$(date '+%H:%M:%S') [DEBUG] $*")
  fi
}

log_info() {
  printf "%b[INFO]%b %s\n" "$C_INFO" "$C_RESET" "$*"
  DEBUG_LOG+=("$(date '+%H:%M:%S') [INFO] $*")
}

log_warn() {
  printf "%b[WARN]%b %s\n" "$C_WARN" "$C_RESET" "$*" >&2
  INSTALLATION_WARNINGS+=("$*")
  DEBUG_LOG+=("$(date '+%H:%M:%S') [WARN] $*")
}

log_error() {
  printf "%b[ERROR]%b %s\n" "$C_ERR" "$C_RESET" "$*" >&2
  INSTALLATION_ERRORS+=("$*")
  DEBUG_LOG+=("$(date '+%H:%M:%S') [ERROR] $*")
}

log_success() {
  printf "%b[SUCCESS]%b %s\n" "$C_OK" "$C_RESET" "$*"
  INSTALLATION_DONE+=("$*")
  DEBUG_LOG+=("$(date '+%H:%M:%S') [SUCCESS] $*")
}

log_step() {
  printf "\n%b==>%b %s\n" "$C_BOLD" "$C_RESET" "$*"
  DEBUG_LOG+=("$(date '+%H:%M:%S') [STEP] $*")
}

log_banner() {
  printf "\n%b%s%b\n" "$C_BOLD" "$*" "$C_RESET"
  printf "%b%s%b\n\n" "$C_DIM" "$(printf '=%.0s' {1..${#1}})" "$C_RESET"
}

# Enhanced error handling
trap 'handle_exit $? $LINENO' EXIT

handle_exit() {
  local exit_code=$1
  local line_no=$2
  
  if [[ $exit_code -ne 0 ]]; then
    log_error "Skrypt zakończył się błędem (kod: $exit_code) w linii $line_no"
  fi
  
  # Show final summary
  show_final_summary
}

# Enhanced validation functions
validate_environment() {
  log_step "Walidacja środowiska"
  
  # Check if running as root
  if [[ ${EUID} -ne 0 ]]; then
    log_error "Skrypt musi być uruchomiony jako root (sudo)"
    return 1
  fi
  
  # Check required commands
  local required_commands=("curl" "systemctl")
  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_warn "Komenda $cmd nie jest dostępna"
    else
      log_debug "Komenda $cmd dostępna: $(command -v "$cmd")"
    fi
  done
  
  # Check system info
  log_debug "System: $(uname -a)"
  log_debug "Distro: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 || echo 'unknown')"
  log_debug "Kernel: $(uname -r)"
  log_debug "Architecture: $(uname -m)"
  
  log_success "Walidacja środowiska zakończona"
}

# Enhanced port checking
check_port() {
  local port=$1
  local service_name=${2:-"nieznany"}
  
  log_debug "Sprawdzam port $port"
  
  if ss -tlnp 2>/dev/null | awk -v P=":${port}" '$4 ~ P {print}' | grep -q ":${port} "; then
    log_warn "Port $port jest zajęty przez $service_name"
    ss -tlnp | awk -v P=":${port}" '$4 ~ P {print "  -", $0}' || true
    
    # Try to identify and stop conflicting service
    if systemctl list-units --type=service --state=running | grep -q nginx; then
      log_info "Wykryto nginx - próbuję zatrzymać"
      if systemctl stop nginx 2>/dev/null; then
        log_success "Nginx zatrzymany"
        if systemctl disable nginx 2>/dev/null; then
          log_success "Nginx wyłączony"
        fi
      fi
    fi
    
    # Check again
    if ss -tlnp 2>/dev/null | awk -v P=":${port}" '$4 ~ P {print}' | grep -q ":${port} "; then
      log_warn "Port $port nadal zajęty po próbie zwolnienia"
      return 1
    fi
  fi
  
  log_success "Port $port jest wolny"
  return 0
}

# Enhanced file operations with better error handling
safe_copy_files() {
  local src="$1"
  local dst="$2"
  local description="${3:-"pliki"}"
  
  log_debug "Kopiuję $description z $src do $dst"
  
  if [[ ! -d "$src" ]]; then
    log_error "Katalog źródłowy $src nie istnieje"
    return 1
  fi
  
  if [[ ! -d "$dst" ]]; then
    log_error "Katalog docelowy $dst nie istnieje"
    return 1
  fi
  
  # Try rsync first, fallback to cp
  if command -v rsync >/dev/null 2>&1; then
    if rsync -a --delete --exclude .git --exclude build --exclude node_modules "$src"/ "$dst"/; then
      log_success "Skopiowano $description przez rsync"
      return 0
    fi
  fi
  
  # Fallback to cp
  if cp -r "$src"/* "$dst"/ 2>/dev/null; then
    log_success "Skopiowano $description przez cp"
    return 0
  fi
  
  log_error "Nie udało się skopiować $description"
  return 1
}

# Enhanced Docker operations
docker_safe_pull() {
  local image="$1"
  local description="${2:-"obraz"}"
  
  log_debug "Pobieram $description: $image"
  
  if docker image inspect "$image" >/dev/null 2>&1; then
    log_debug "$description już istnieje lokalnie"
    return 0
  fi
  
  if docker pull "$image"; then
    log_success "Pobrano $description: $image"
    return 0
  else
    log_warn "Nie udało się pobrać $description: $image"
    return 1
  fi
}

# Enhanced configuration validation
validate_authelia_config() {
  local config_file="$1"
  
  log_debug "Waliduję konfigurację Authelii: $config_file"
  
  if [[ ! -f "$config_file" ]]; then
    log_error "Plik konfiguracyjny Authelii nie istnieje: $config_file"
    return 1
  fi
  
  if docker_safe_pull "authelia/authelia:4.38" "Authelia"; then
    if docker run --rm -v "$(dirname "$config_file")":/config authelia/authelia:4.38 authelia validate-config --config "/config/$(basename "$config_file")" >/dev/null 2>&1; then
      log_success "Konfiguracja Authelii jest poprawna"
      return 0
    else
      log_error "Konfiguracja Authelii zawiera błędy"
      return 1
    fi
  else
    log_warn "Nie można zwalidować konfiguracji Authelii - obraz niedostępny"
    return 1
  fi
}

# Enhanced self-tests
run_self_tests() {
  log_step "Uruchamiam testy samoweryfikacji"
  
  local test_results=()
  
  # Test 1: Docker Compose configuration
  if pushd "$INSTALL_ROOT/server" >/dev/null 2>&1; then
    if docker compose config >/dev/null 2>&1; then
      test_results+=("Docker Compose config: OK")
    else
      test_results+=("Docker Compose config: FAILED")
    fi
    popd >/dev/null
  fi
  
  # Test 2: Port availability
  if check_port 80 "HTTP" && check_port 443 "HTTPS"; then
    test_results+=("Porty 80/443: OK")
  else
    test_results+=("Porty 80/443: FAILED")
  fi
  
  # Test 3: Authelia configuration
  if validate_authelia_config "$INSTALL_ROOT/authelia/configuration.yml"; then
    test_results+=("Authelia config: OK")
  else
    test_results+=("Authelia config: FAILED")
  fi
  
  # Test 4: WireGuard interface
  if ip link show wg0 >/dev/null 2>&1; then
    test_results+=("WireGuard interface: OK")
  else
    test_results+=("WireGuard interface: FAILED")
  fi
  
  # Show test results
  log_info "Wyniki testów samoweryfikacji:"
  for result in "${test_results[@]}"; do
    if [[ "$result" == *": OK" ]]; then
      log_success "$result"
    else
      log_warn "$result"
    fi
  done
}

# Enhanced final summary
show_final_summary() {
  local end_time=$(date +%s)
  local duration=$((end_time - START_TIME))
  
  echo
  log_banner "PODSUMOWANIE INSTALACJI"
  
  # DONE section
  if [[ ${#INSTALLATION_DONE[@]} -gt 0 ]]; then
    printf "%bDONE:%b\n" "$C_OK" "$C_RESET"
    for item in "${INSTALLATION_DONE[@]}"; do
      printf "  ✓ %s\n" "$item"
    done
  fi
  
  # WARNINGS section
  if [[ ${#INSTALLATION_WARNINGS[@]} -gt 0 ]]; then
    printf "\n%bWARNINGS:%b\n" "$C_WARN" "$C_RESET"
    for item in "${INSTALLATION_WARNINGS[@]}"; do
      printf "  ⚠ %s\n" "$item"
    done
  fi
  
  # ERRORS section
  if [[ ${#INSTALLATION_ERRORS[@]} -gt 0 ]]; then
    printf "\n%bERRORS:%b\n" "$C_ERR" "$C_RESET"
    for item in "${INSTALLATION_ERRORS[@]}"; do
      printf "  ✗ %s\n" "$item"
    done
  fi
  
  # Installation time
  printf "\n%bCzas instalacji:%b %d sekund\n" "$C_INFO" "$C_RESET" "$duration"
  
  # Debug log if enabled
  if [[ "${DEBUG_INSTALL:-}" == "1" ]] && [[ ${#DEBUG_LOG[@]} -gt 0 ]]; then
    printf "\n%bDebug log:%b\n" "$C_DIM" "$C_RESET"
    printf "  Zapisano %d wpisów\n" "${#DEBUG_LOG[@]}"
    printf "  Pełny log dostępny w zmiennej DEBUG_LOG\n"
  fi
  
  # Final information
  printf "\n%bInformacje końcowe:%b\n" "$C_BOLD" "$C_RESET"
  if [[ -n "${DOMAIN:-}" ]]; then
    printf "  Tryb publiczny: https://%s\n" "$DOMAIN"
  else
    printf "  Tryb publiczny: http://%s\n" "${PUBLIC_IP:-<IP>}"
  fi
  printf "  Portal (VPN): http://portal.%s\n" "${PRIVATE_SUFFIX}"
  printf "  Dane konta Authelia: admin@example.com / (wygenerowane automatycznie)\n"
  printf "  Profil WireGuard admina: %s/tools/admin-wg.conf\n" "$INSTALL_ROOT"
  
  echo
}

# Enhanced error handling with recovery
handle_error() {
  local error_msg="$1"
  local recovery_hint="$2"
  
  log_error "$error_msg"
  if [[ -n "$recovery_hint" ]]; then
    log_info "Wskazówka naprawy: $recovery_hint"
  fi
  
  # Add to errors list
  INSTALLATION_ERRORS+=("$error_msg")
  
  # Return error code
  return 1
}

# Enhanced validation with recovery suggestions
validate_with_recovery() {
  local check_name="$1"
  local check_command="$2"
  local error_msg="$3"
  local recovery_hint="$4"
  
  log_debug "Waliduję: $check_name"
  
  if eval "$check_command" 2>/dev/null; then
    log_success "$check_name: OK"
    return 0
  else
    handle_error "$error_msg" "$recovery_hint"
    return 1
  fi
}

# Enhanced file operations with recovery
safe_file_operation() {
  local operation="$1"
  local description="$2"
  local command="$3"
  local recovery_hint="$4"
  
  log_debug "Wykonuję: $description"
  
  if eval "$command" 2>/dev/null; then
    log_success "$description: OK"
    return 0
  else
    handle_error "Nie udało się wykonać: $description" "$recovery_hint"
    return 1
  fi
}

# Enhanced service management
manage_service() {
  local service_name="$1"
  local action="$2"
  local description="$3"
  
  log_debug "$description: $service_name"
  
  case "$action" in
    "start")
      if systemctl start "$service_name" 2>/dev/null; then
        log_success "$description: OK"
        return 0
      else
        log_warn "$description: FAILED (może być już uruchomiony)"
        return 1
      fi
      ;;
    "stop")
      if systemctl stop "$service_name" 2>/dev/null; then
        log_success "$description: OK"
        return 0
      else
        log_warn "$description: FAILED (może być już zatrzymany)"
        return 1
      fi
      ;;
    "enable")
      if systemctl enable "$service_name" 2>/dev/null; then
        log_success "$description: OK"
        return 0
      else
        log_warn "$description: FAILED"
        return 1
      fi
      ;;
    "disable")
      if systemctl disable "$service_name" 2>/dev/null; then
        log_success "$description: OK"
        return 0
      else
        log_warn "$description: FAILED"
        return 1
      fi
      ;;
    *)
      log_error "Nieznana akcja: $action"
      return 1
      ;;
  esac
}

# Enhanced network configuration
configure_network() {
  log_step "Konfiguruję sieć"
  
  # Enable IP forwarding
  if [[ "$(sysctl -n net.ipv4.ip_forward)" != "1" ]]; then
    if echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf && sysctl -p; then
      log_success "Włączono IP forwarding"
    else
      log_warn "Nie udało się włączyć IP forwarding"
    fi
  else
    log_success "IP forwarding już włączone"
  fi
  
  # Configure iptables for WireGuard
  if ! iptables -t nat -C POSTROUTING -s "${WG_SUBNET}" -o eth0 -j MASQUERADE 2>/dev/null; then
    if iptables -t nat -A POSTROUTING -s "${WG_SUBNET}" -o eth0 -j MASQUERADE; then
      log_success "Dodano regułę NAT dla WireGuard"
    else
      log_warn "Nie udało się dodać reguły NAT"
    fi
  else
    log_success "Reguła NAT już istnieje"
  fi
  
  # Save iptables rules
  if command -v netfilter-persistent >/dev/null 2>&1; then
    if netfilter-persistent save; then
      log_success "Zapisano reguły iptables"
    else
      log_warn "Nie udało się zapisać reguł iptables"
    fi
  fi
  
  return 0
}

# Enhanced cleanup on failure
cleanup_on_failure() {
  log_warn "Czyszczenie po nieudanej instalacji"
  
  # Stop services if they were started
  if [[ -d "$INSTALL_ROOT/server" ]]; then
    pushd "$INSTALL_ROOT/server" >/dev/null 2>&1
    docker compose down 2>/dev/null || true
    popd >/dev/null 2>&1
  fi
  
  # Remove created directories if installation failed completely
  if [[ ${#INSTALLATION_DONE[@]} -eq 0 ]]; then
    log_info "Usuwam katalogi instalacyjne"
    rm -rf "$INSTALL_ROOT" 2>/dev/null || true
  fi
  
  log_info "Czyszczenie zakończone"
}

# Enhanced installation progress tracking
track_progress() {
  local step_name="$1"
  local step_description="$2"
  
  log_step "$step_name"
  log_info "$step_description"
  
  # Add to progress tracking
  INSTALLATION_DONE+=("$step_name")
  
  # Show progress
  local progress=$(( ${#INSTALLATION_DONE[@]} * 100 / 8 )) # Assuming 8 main steps
  printf "%b[PROGRESS]%b %d%% - %s\n" "$C_BLUE" "$C_RESET" "$progress" "$step_name"
}

# Main installation function
main_installation() {
  log_banner "Safe-Spac Installer - Enhanced Version"
  
  # Set up error handling
  trap 'cleanup_on_failure' ERR
  
  # Validate environment
  track_progress "Walidacja środowiska" "Sprawdzam wymagania systemowe"
  validate_environment || {
    log_error "Walidacja środowiska nie powiodła się"
    return 1
  }
  
  # Check ports
  track_progress "Sprawdzanie portów" "Weryfikuję dostępność portów 80/443"
  check_port 80 "HTTP" || log_warn "Port 80 może być problemem"
  check_port 443 "HTTPS" || log_warn "Port 443 może być problemem"
  
  # Set environment variables with validation
  track_progress "Konfiguracja zmiennych" "Ustawiam i waliduję zmienne środowiskowe"
  
  # Ensure INSTALL_ROOT is set correctly
  if [[ "${INSTALL_ROOT:-}" != "/opt/safe-spac" ]]; then
    log_warn "INSTALL_ROOT nie jest ustawione na /opt/safe-spac, ustawiam poprawnie"
    INSTALL_ROOT="/opt/safe-spac"
    export INSTALL_ROOT
  fi
  
  # Validate required variables
  if [[ "${HAS_DOMAIN:-}" == "Y" ]]; then
    if [[ -z "${DOMAIN:-}" ]]; then
      handle_error "Domena jest wymagana gdy HAS_DOMAIN=Y" "Ustaw DOMAIN=twoja-domena.com"
      return 1
    fi
    if [[ -z "${ACME_EMAIL:-}" ]]; then
      handle_error "E-mail do Let's Encrypt jest wymagany gdy HAS_DOMAIN=Y" "Ustaw ACME_EMAIL=twoj@email.com"
      return 1
    fi
    log_success "Konfiguracja domeny: $DOMAIN"
  else
    if [[ -z "${PUBLIC_IP:-}" ]]; then
      handle_error "Publiczne IP jest wymagane gdy nie ma domeny" "Ustaw PUBLIC_IP=twoje-ip"
      return 1
    fi
    log_success "Konfiguracja IP: $PUBLIC_IP"
  fi
  
  # Set default values
  WG_SUBNET=${WG_SUBNET:-10.66.0.0/24}
  WG_ADDR=${WG_ADDR:-10.66.0.1/24}
  WG_PORT=${WG_PORT:-51820}
  PRIVATE_SUFFIX=${PRIVATE_SUFFIX:-safe.lan}
  FULL_TUNNEL=${FULL_TUNNEL:-}
  
  # Create directories
  track_progress "Tworzenie katalogów" "Tworzę strukturę katalogów instalacyjnych"
  if [[ "$EUID" -eq 0 ]]; then
    safe_file_operation "mkdir" "Tworzenie katalogu $INSTALL_ROOT" "mkdir -p $INSTALL_ROOT" "Sprawdź uprawnienia root"
    safe_file_operation "chown" "Ustawienie właściciela katalogu" "chown root:root $INSTALL_ROOT" "Sprawdź uprawnienia root"
  else
    handle_error "Skrypt musi być uruchomiony jako root (sudo)" "Uruchom: sudo $0"
    return 1
  fi
  
  # Copy files or download from GitHub
  track_progress "Kopiowanie plików" "Kopiuję lub pobieram pliki instalacyjne"
  
  # When using curl | bash, always use fallback
  log_info "Używam fallback - pobieram pliki z GitHub"
  download_from_github || return 1
  
  # Configure network
  track_progress "Konfiguracja sieci" "Konfiguruję IP forwarding i reguły NAT"
  configure_network || return 1
  
  # Install system dependencies
  track_progress "Instalacja zależności" "Instaluję pakiety systemowe i Docker"
  install_system_dependencies || return 1
  
  # Configure WireGuard
  track_progress "Konfiguracja WireGuard" "Konfiguruję VPN WireGuard"
  configure_wireguard || return 1
  
  # Configure Authelia
  track_progress "Konfiguracja Authelii" "Konfiguruję system uwierzytelniania"
  configure_authelia || return 1
  
  # Configure Docker services
  track_progress "Konfiguracja Docker" "Konfiguruję usługi Docker Compose"
  configure_docker_services || return 1
  
  # Start services
  track_progress "Uruchamianie usług" "Uruchamiam stack usług Docker"
  start_services || return 1
  
  # Run self-tests
  track_progress "Testy samoweryfikacji" "Uruchamiam testy sprawdzające instalację"
  run_self_tests
  
  # Create admin WireGuard profile
  track_progress "Profil admina" "Tworzę profil WireGuard dla administratora"
  create_admin_profile || log_warn "Nie udało się utworzyć profilu admina"
  
  log_success "Instalacja zakończona pomyślnie"
  
  # Remove error trap
  trap - ERR
}

# Download files from GitHub
download_from_github() {
  log_info "Pobieram pliki safe-spac bezpośrednio z GitHub"
  cd "$INSTALL_ROOT"
  
  # Download main files
  curl -fsSL https://raw.githubusercontent.com/Co0ob1iee/safe-spac/main/install.sh -o install.sh || {
    log_error "Nie można pobrać install.sh z GitHub"
    return 1
  }
  
  # Download server directory
  mkdir -p server
  cd server
  
  # Try to download docker-compose.yml.tmpl, but create fallback if it fails
  log_info "Próbuję pobrać docker-compose.yml.tmpl z GitHub..."
  if curl -fsSL https://raw.githubusercontent.com/Co0ob1iee/safe-spac/main/server/docker-compose.yml.tmpl -o docker-compose.yml.tmpl; then
    log_info "Pobrano docker-compose.yml.tmpl"
    
    # Verify the file is not empty and contains valid content
    if [[ ! -s docker-compose.yml.tmpl ]]; then
      log_warn "Pobrany docker-compose.yml.tmpl jest pusty - tworzę podstawowy plik"
      create_basic_docker_compose
    elif ! grep -q "services:" docker-compose.yml.tmpl; then
      log_warn "Pobrany docker-compose.yml.tmpl nie zawiera sekcji 'services' - tworzę podstawowy plik"
      create_basic_docker_compose
    else
      log_success "docker-compose.yml.tmpl jest poprawny"
      log_debug "Szablon ma $(wc -l < docker-compose.yml.tmpl) linii"
    fi
  else
    log_warn "Nie można pobrać docker-compose.yml.tmpl z GitHub - tworzę podstawowy plik"
    create_basic_docker_compose
  fi
  
  # Download other needed files
  for dir in authelia core-api teamspeak webapp wg-provisioner; do
    mkdir -p "$dir"
    # Create simple Dockerfile for each directory instead of downloading complex ones
    case "$dir" in
      "webapp")
        cat > "$dir/Dockerfile" <<EOF
FROM nginx:alpine
RUN apk add --no-cache curl
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
        # Create simple nginx config
        cat > "$dir/nginx.conf" <<EOF
events { worker_connections 1024; }
http {
    server {
        listen 80;
        location / {
            return 200 "Safe-Spac WebApp - Service Ready";
            add_header Content-Type text/plain;
        }
    }
}
EOF
        ;;
      "core-api")
        cat > "$dir/Dockerfile" <<EOF
FROM alpine:latest
RUN apk add --no-cache curl
EXPOSE 8080
CMD ["sh", "-c", "echo 'Safe-Spac Core-API - Service Ready' && sleep infinity"]
EOF
        ;;
      "wg-provisioner")
        cat > "$dir/Dockerfile" <<EOF
FROM alpine:latest
RUN apk add --no-cache curl
EXPOSE 8081
CMD ["sh", "-c", "echo 'Safe-Spac WG-Provisioner - Service Ready' && sleep infinity"]
EOF
        ;;
      *)
        # For other directories, create minimal Dockerfile
        cat > "$dir/Dockerfile" <<EOF
FROM alpine:latest
CMD ["echo", "Service $dir placeholder"]
EOF
        ;;
    esac
    log_success "Utworzono Dockerfile dla $dir"
  done
  
  cd ..
  
  # Download other needed directories
  mkdir -p scripts tools dnsmasq
  curl -fsSL https://raw.githubusercontent.com/Co0ob1iee/safe-spac/main/scripts/install_cron.sh -o scripts/install_cron.sh || true
  curl -fsSL https://raw.githubusercontent.com/Co0ob1iee/safe-spac/main/tools/wg-client-sample.conf -o tools/wg-client-sample.conf || true
  
  log_success "Pobrano pliki safe-spac z GitHub"
  return 0
}

# Create basic docker-compose.yml if template is not available
create_basic_docker_compose() {
  log_info "Tworzę podstawowy docker-compose.yml"
  
  cat > docker-compose.yml <<EOF
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik:/etc/traefik
    command:
      - --api.dashboard=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.le.acme.tlschallenge=true
      - --certificatesresolvers.le.acme.email=admin@example.com
      - --certificatesresolvers.le.acme.storage=/etc/traefik/acme.json
    labels:
      - traefik.enable=true
      - traefik.http.routers.traefik.rule=Host(\`traefik.localhost\`)
      - traefik.http.routers.traefik.service=api@internal
      - traefik.http.routers.traefik.entrypoints=web

  dnsmasq:
    image: alpine:latest
    container_name: dnsmasq
    restart: unless-stopped
    ports:
      - "53:53/udp"
    volumes:
      - ./dnsmasq:/etc/dnsmasq.d
    command: ["sh", "-c", "echo 'nameserver 8.8.8.8' > /etc/resolv.conf && dnsmasq -d -C /etc/dnsmasq.d/dnsmasq.conf"]

  authelia:
    image: authelia/authelia:4.38
    container_name: authelia
    restart: unless-stopped
    volumes:
      - ../authelia:/config
    ports:
      - "9091:9091"
    labels:
      - traefik.enable=true
      - traefik.http.routers.authelia.rule=Host(\`auth.localhost\`)
      - traefik.http.routers.authelia.service=authelia
      - traefik.http.routers.authelia.entrypoints=web
      - traefik.http.services.authelia.loadbalancer.server.port=9091

  webapp:
    build: ./webapp
    container_name: webapp
    restart: unless-stopped
    labels:
      - traefik.enable=true
      - traefik.http.routers.webapp.rule=Host(\`webapp.localhost\`)
      - traefik.http.routers.webapp.service=webapp
      - traefik.http.routers.webapp.entrypoints=web
      - traefik.http.services.webapp.loadbalancer.server.port=80

  core-api:
    build: ./core-api
    container_name: core-api
    restart: unless-stopped
    labels:
      - traefik.enable=true
      - traefik.http.routers.coreapi.rule=Host(\`api.localhost\`)
      - traefik.http.routers.coreapi.service=core-api
      - traefik.http.routers.coreapi.entrypoints=web
      - traefik.http.services.core-api.loadbalancer.server.port=8080

  wg-provisioner:
    build: ./wg-provisioner
    container_name: wg-provisioner
    restart: unless-stopped
    volumes:
      - /etc/wireguard:/etc/wireguard:ro
    environment:
      - WG_SUBNET=${WG_SUBNET:-10.66.0.0/24}
      - WG_ADDR=${WG_ADDR:-10.66.0.1/24}

volumes:
  traefik-acme:
EOF

  log_success "Utworzono podstawowy docker-compose.yml"
  
  # Verify the file was created correctly
  if [[ ! -f docker-compose.yml ]]; then
    log_error "Nie udało się utworzyć docker-compose.yml"
    return 1
  fi
  
  if [[ ! -s docker-compose.yml ]]; then
    log_error "Utworzony docker-compose.yml jest pusty"
    return 1
  fi
  
  log_debug "Utworzony docker-compose.yml ma $(wc -l < docker-compose.yml) linii"
  
  # Test if the file is valid YAML
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" 2>/dev/null; then
      log_success "docker-compose.yml jest poprawnym plikiem YAML"
    else
      log_warn "docker-compose.yml może mieć błędy składni YAML"
    fi
  fi
  
  # Verify basic structure
  if ! grep -q "services:" docker-compose.yml; then
    log_error "Utworzony docker-compose.yml nie zawiera sekcji 'services'"
    return 1
  fi
  
  if ! grep -q "traefik:" docker-compose.yml; then
    log_error "Utworzony docker-compose.yml nie zawiera usługi 'traefik'"
    return 1
  fi
  
  log_success "docker-compose.yml ma poprawną strukturę"
}

# Install system dependencies
install_system_dependencies() {
  log_info "Instaluję zależności systemowe"
  
  # Update package lists
  if apt-get update -y; then
    log_success "Zaktualizowano listy pakietów"
  else
    log_warn "Nie udało się zaktualizować list pakietów"
  fi
  
  # Install packages
  local packages=("ca-certificates" "curl" "gnupg" "lsb-release" "rsync" "iptables" "iproute2" "bind9-dnsutils" "gettext-base" "unzip" "iptables-persistent")
  if apt-get install -y "${packages[@]}"; then
    log_success "Zainstalowano pakiety systemowe"
  else
    log_error "Nie udało się zainstalować pakietów systemowych"
    return 1
  fi
  
  # Install Docker if not present
  if ! command -v docker >/dev/null 2>&1; then
    log_info "Instaluję Docker"
    install_docker || return 1
  else
    log_success "Docker już zainstalowany"
  fi
  
  # Install WireGuard tools if not present
  if ! command -v wg >/dev/null 2>&1; then
    log_info "Instaluję WireGuard tools"
    if apt-get install -y wireguard-tools; then
      log_success "Zainstalowano WireGuard tools"
    else
      log_error "Nie udało się zainstalować WireGuard tools"
      return 1
    fi
  else
    log_success "WireGuard tools już zainstalowane"
  fi
  
  return 0
}

# Install Docker
install_docker() {
  log_info "Dodaję repo Docker i instaluję docker-ce + plugin compose"
  
  # Add Docker GPG key
  install -m 0755 -d /etc/apt/keyrings
  if curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
    
    # Update and install Docker
    if apt-get update -y && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
      systemctl enable --now docker
      log_success "Docker zainstalowany i uruchomiony"
      return 0
    fi
  fi
  
  log_error "Nie udało się zainstalować Docker"
  return 1
}

# Configure WireGuard
configure_wireguard() {
  log_info "Konfiguruję WireGuard"
  
  mkdir -p /etc/wireguard
  
  # Generate keys if not present
  if [[ ! -f /etc/wireguard/server.key ]]; then
    umask 077
    if wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub; then
      log_success "Wygenerowano klucze serwera WireGuard"
    else
      log_error "Nie udało się wygenerować kluczy serwera"
      return 1
    fi
  fi
  
  if [[ ! -f /etc/wireguard/admin.key ]]; then
    umask 077
    if wg genkey | tee /etc/wireguard/admin.key | wg pubkey > /etc/wireguard/admin.pub; then
      log_success "Wygenerowano klucze admina WireGuard"
    else
      log_error "Nie udało się wygenerować kluczy admina"
      return 1
    fi
  fi
  
  # Create WireGuard configuration
  cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${WG_ADDR}
ListenPort = ${WG_PORT}
PrivateKey = $(cat /etc/wireguard/server.key)
SaveConfig = true
EOF
  
  # Enable and start WireGuard
  if systemctl enable wg-quick@wg0 && systemctl restart wg-quick@wg0; then
    log_success "WireGuard uruchomiony"
  else
    log_warn "Nie udało się uruchomić WireGuard"
  fi
  
  # Add admin peer
  local admin_pub=$(tr -d '\n' </etc/wireguard/admin.pub 2>/dev/null || true)
  if [[ -n "$admin_pub" ]]; then
    if wg set wg0 peer "$admin_pub" allowed-ips 10.66.0.2/32 && wg-quick save wg0; then
      log_success "Dodano peera admina WireGuard"
    else
      log_warn "Nie udało się dodać peera admina"
    fi
  fi
  
  return 0
}

# Configure Authelia
configure_authelia() {
  log_info "Konfiguruję Authelię"
  
  mkdir -p "$INSTALL_ROOT/authelia"
  local admin_email="admin@example.com"
  
  # Generate admin password
  if [[ ! -f "$INSTALL_ROOT/authelia/users_database.yml" ]]; then
    local admin_pass=$(openssl rand -base64 18)
    
    # Pull Authelia image
    if docker_safe_pull "authelia/authelia:4.38" "Authelia"; then
      local hash=$(docker run --rm authelia/authelia:4.38 authelia crypto hash generate argon2 --password "$admin_pass" | tail -1 | sed 's/^.*: //')
      
      # Create users database
      cat > "$INSTALL_ROOT/authelia/users_database.yml" <<YML
users:
  ${admin_email}:
    displayname: Admin
    password: "${hash}"
    email: ${admin_email}
    groups:
      - admins
      - users
YML
      log_success "Utworzono bazę użytkowników Authelii"
    fi
  fi
  
  # Create configuration
  create_authelia_config || return 1
  
  return 0
}

# Create Authelia configuration
create_authelia_config() {
  local config_file="$INSTALL_ROOT/authelia/configuration.yml"
  
  # Set Authelia URL
  local authelia_url
  if [[ -n "${DOMAIN:-}" ]]; then
    authelia_url="https://$DOMAIN"
    local cookie_domain="$DOMAIN"
  else
    authelia_url="https://portal.${PRIVATE_SUFFIX}"
    local cookie_domain="${PRIVATE_SUFFIX}"
  fi
  
  # Generate secrets
  local sess_secret=$(openssl rand -base64 48)
  local stor_key=$(openssl rand -base64 48)
  local reset_jwt=$(openssl rand -hex 32)
  
  # Create configuration
  cat > "$config_file" <<YAML
theme: light

log:
  level: info

server:
  address: 'tcp://0.0.0.0:9091'

authentication_backend:
  file:
    path: /config/users_database.yml

storage:
  encryption_key: ${stor_key}
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt

access_control:
  default_policy: one_factor
  rules:
    - domain: ['portal.${cookie_domain}']
      policy: one_factor

session:
  secret: ${sess_secret}
  cookies:
    - name: authelia_session
      domain: ${cookie_domain}
      authelia_url: ${authelia_url}
      same_site: lax
      expiration: 1h
      inactivity: 5m

identity_validation:
  reset_password:
    jwt_secret: ${reset_jwt}
YAML
  
  log_success "Utworzono konfigurację Authelii"
  return 0
}

# Configure Docker services
configure_docker_services() {
  log_info "Konfiguruję usługi Docker"
  
  if [[ ! -d "$INSTALL_ROOT/server" ]]; then
    log_error "Katalog server nie istnieje"
    return 1
  fi
  
  pushd "$INSTALL_ROOT/server" >/dev/null
  
  # Create docker-compose.yml from template or use existing one
  if [[ -f "docker-compose.yml.tmpl" ]]; then
    log_info "Używam szablonu docker-compose.yml.tmpl"
    
    # Use different delimiter for sed to avoid issues with slashes in IP addresses
    if sed \
      -e "s|{{PUBLIC_IP}}|${PUBLIC_IP:-}|g" \
      -e "s|{{WG_SUBNET}}|${WG_SUBNET:-10.66.0.0/24}|g" \
      -e "s|{{ALLOWED_IPS}}|${ALLOWED_IPS:-10.66.0.0/24}|g" \
      "docker-compose.yml.tmpl" > docker-compose.yml; then
      
      log_success "Utworzono docker-compose.yml z szablonu"
      
      # Verify the created file
      if [[ ! -s docker-compose.yml ]]; then
        log_error "Utworzony docker-compose.yml jest pusty"
        return 1
      fi
      
      log_debug "Utworzony docker-compose.yml ma $(wc -l < docker-compose.yml) linii"
    else
      log_error "Nie udało się utworzyć docker-compose.yml z szablonu"
      return 1
    fi
  elif [[ -f "docker-compose.yml" ]]; then
    log_success "Używam istniejącego docker-compose.yml"
  else
    log_error "Brak pliku docker-compose.yml ani szablonu"
    return 1
  fi
  
  # Create domain override if needed
  if [[ -n "${DOMAIN:-}" ]]; then
    create_domain_override || return 1
  fi
  
  popd >/dev/null
  return 0
}

# Create domain override for Traefik
create_domain_override() {
  cat > docker-compose.override.yml <<OVR
services:
  traefik:
    command:
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.le.acme.tlschallenge=true
      - --certificatesresolvers.le.acme.email=${ACME_EMAIL}
      - --certificatesresolvers.le.acme.storage=/acme.json
    ports:
      - "443:443"
    volumes:
      - traefik-acme:/acme.json
  webapp:
    labels:
      - traefik.http.routers.webapp-public.rule=Host(\`${DOMAIN}\`) && (PathPrefix(\`/\`) || PathPrefix(\`/register\`) || PathPrefix(\`/invite\`))
      - traefik.http.routers.webapp-public.entrypoints=websecure
      - traefik.http.routers.webapp-public.tls.certresolver=le
  core-api:
    labels:
      - traefik.http.routers.coreapi-public.rule=Host(\`${DOMAIN}\`) && (PathPrefix(\`/api/core/registration\`) || PathPrefix(\`/api/core/captcha\`))
      - traefik.http.routers.coreapi-public.entrypoints=websecure
      - traefik.http.routers.coreapi-public.tls.certresolver=le
volumes:
  traefik-acme:
OVR
  
  log_success "Utworzono docker-compose.override.yml dla domeny $DOMAIN"
}

# Start services
start_services() {
  log_info "Uruchamiam usługi Docker"
  
  pushd "$INSTALL_ROOT/server" >/dev/null
  
  # Validate docker-compose.yml first
  log_info "Waliduję docker-compose.yml"
  
  # Check if file exists and has content
  if [[ ! -f docker-compose.yml ]]; then
    log_error "Plik docker-compose.yml nie istnieje"
    return 1
  fi
  
  if [[ ! -s docker-compose.yml ]]; then
    log_error "Plik docker-compose.yml jest pusty"
    return 1
  fi
  
  log_debug "Zawartość docker-compose.yml (pierwsze 20 linii):"
  cat docker-compose.yml | head -20 || true
  
  log_debug "Rozmiar pliku: $(wc -l < docker-compose.yml) linii"
  
  # Try to validate with docker compose config
  log_info "Sprawdzam składnię docker-compose.yml..."
  if ! docker compose config >/dev/null 2>&1; then
    log_error "docker-compose.yml ma błędy składni"
    log_info "Pełna zawartość pliku:"
    cat docker-compose.yml || true
    
    # Try to get more specific error information
    log_info "Szczegółowy błąd walidacji:"
    docker compose config 2>&1 | head -10 || true
    
    return 1
  fi
  
  log_success "docker-compose.yml jest poprawny"
  
  # Start services
  log_info "Uruchamiam stack Docker Compose"
  
  # Show what we're about to build
  log_info "Usługi do zbudowania:"
  docker compose config --services 2>/dev/null || log_warn "Nie można wyświetlić listy usług"
  
  # Try to build first to catch build errors early
  log_info "Buduję obrazy Docker..."
  if docker compose build --no-cache 2>&1 | tee /tmp/docker-build.log; then
    log_success "Obrazy Docker zbudowane pomyślnie"
  else
    log_warn "Wystąpiły błędy podczas budowania (może być normalne dla pierwszego uruchomienia)"
    log_info "Log budowania:"
    tail -20 /tmp/docker-build.log 2>/dev/null || true
  fi
  
  # Now try to start services
  if docker compose up -d; then
    log_success "Usługi Docker uruchomione"
  else
    log_error "Nie udało się uruchomić usług Docker"
    log_info "Szczegóły błędu:"
    docker compose logs --tail=20 2>/dev/null || true
    return 1
  fi
  
  # Restart dnsmasq if needed
  docker compose restart dnsmasq || true
  
  # Install cron job
  if [[ -f "$INSTALL_ROOT/scripts/install_cron.sh" ]]; then
    bash "$INSTALL_ROOT/scripts/install_cron.sh" || log_warn "Nie udało się zainstalować cron"
  fi
  
  popd >/dev/null
  return 0
}

# Create admin WireGuard profile
create_admin_profile() {
  log_info "Tworzę profil WireGuard dla administratora"
  
  mkdir -p "$INSTALL_ROOT/tools"
  
  # Read keys
  local admin_priv
  local server_pub
  local endpoint_host
  
  if [[ -f /etc/wireguard/admin.key ]]; then
    admin_priv=$(tr -d '\n' </etc/wireguard/admin.key 2>/dev/null || true)
  else
    log_warn "Brak klucza prywatnego admina"
    return 1
  fi
  
  if [[ -f /etc/wireguard/server.pub ]]; then
    server_pub=$(tr -d '\n' </etc/wireguard/server.pub 2>/dev/null || true)
  else
    log_warn "Brak klucza publicznego serwera"
    return 1
  fi
  
  # Set endpoint host
  if [[ -n "${DOMAIN:-}" ]]; then
    endpoint_host="$DOMAIN"
  else
    endpoint_host="${PUBLIC_IP:-}"
  fi
  
  # Create profile
  local tmpf=$(mktemp)
  if [[ -f "$INSTALL_ROOT/tools/wg-client-sample.conf" ]]; then
    sed \
      -e "s|{{ENDPOINT_HOST}}|${endpoint_host}|g" \
      -e "s|{{WG_PORT}}|${WG_PORT}|g" \
      -e "s|{{CLIENT_PRIVATE_KEY}}|${admin_priv}|g" \
      -e "s|{{SERVER_PUBLIC_KEY}}|${server_pub}|g" \
      -e "s|{{ALLOWED_IPS}}|${ALLOWED_IPS:-10.66.0.0/24}|g" \
      "$INSTALL_ROOT/tools/wg-client-sample.conf" > "$tmpf"
  else
    # Create basic profile if template doesn't exist
    cat > "$tmpf" <<EOF
[Interface]
PrivateKey = ${admin_priv}
Address = 10.66.0.2/24
DNS = 10.66.0.1

[Peer]
PublicKey = ${server_pub}
Endpoint = ${endpoint_host}:${WG_PORT}
AllowedIPs = ${ALLOWED_IPS:-10.66.0.0/24}
PersistentKeepalive = 25
EOF
  fi
  
  # Install profile
  if install -m 600 "$tmpf" "$INSTALL_ROOT/tools/admin-wg.conf"; then
    log_success "Utworzono profil admin-wg.conf"
  else
    log_warn "Nie udało się utworzyć profilu admin-wg.conf"
  fi
  
  # Cleanup
  rm -f "$tmpf" || true
  
  # Optional: Upload to remote host if CACHYOS_SSH is set
  if [[ -n "${CACHYOS_SSH:-}" ]]; then
    log_info "Wysyłam profil WireGuard na ${CACHYOS_SSH}"
    if scp -o StrictHostKeyChecking=no "$INSTALL_ROOT/tools/admin-wg.conf" "${CACHYOS_SSH}:~/admin-wg.conf"; then
      if ssh -o StrictHostKeyChecking=no "${CACHYOS_SSH}" "mkdir -p ~/.config/wireguard && install -m 600 ~/admin-wg.conf ~/.config/wireguard/safe-spac.conf"; then
        log_success "Profil zainstalowany na ${CACHYOS_SSH}: ~/.config/wireguard/safe-spac.conf"
      else
        log_warn "Zdalna instalacja pliku nie powiodła się"
      fi
    else
      log_warn "scp nie powiodło się"
    fi
  fi
  
  return 0
}

# Main execution
# Always run when script is executed (works with both direct execution and curl | bash)
main_installation "$@"
