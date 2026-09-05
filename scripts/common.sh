#!/usr/bin/env bash
# ==============================================================================
# common.sh - Fonctions utilitaires, environnement et allocation de ports
# ==============================================================================
set -euo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

readonly C_RESET='\033[0m' C_RED='\033[0;31m' C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m' C_BLUE='\033[0;34m' C_CYAN='\033[0;36m'

log_info()    { echo -e "${C_BLUE}[INFO]${C_RESET} $*"; }
log_success() { echo -e "${C_GREEN}[OK]${C_RESET} $*"; }
log_warn()    { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
log_error()   { echo -e "${C_RED}[ERREUR]${C_RESET} $*" >&2; }

load_env() {
    local env_file="${1:-.env}"
    if [[ -f "$env_file" ]]; then
        set -a
        # shellcheck disable=SC1090
        source <(grep -E -v '^[[:space:]]*#|^$' "$env_file")
        set +a
    fi
}

get_env_or_default() {
    local key="$1" def="$2" cur="$def"
    if [[ -v "$key" ]]; then
        local val="${!key}"
        [[ -n "$val" ]] && cur="$val"
    fi
    echo "$cur"
}

update_env_var() {
    local key="$1" val="$2" file="$3"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$file"
    else
        echo "${key}=${val}" >> "$file"
    fi
    export "${key}=${val}"
}

detect_pkg_mgr() {
    if command -v dnf5 >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    else
        log_error "Gestionnaire de paquets inconnu." && exit 1
    fi
}

run_sudo() {
    if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

is_port_in_use() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -tuln | grep -E -q ":${port}\b" && return 0
    fi
    (echo > "/dev/tcp/127.0.0.1/${port}") >/dev/null 2>&1 && return 0
    return 1
}

find_free_port() {
    local p="$1"
    while is_port_in_use "$p"; do
        p=$((p + 1))
    done
    echo "$p"
}

generate_password() {
    local len="${1:-20}"
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 32 | tr -dc 'A-Za-z0-9_!@#%' | head -c "$len"
    else
        tr -dc 'A-Za-z0-9_!@#%' < /dev/urandom | head -c "$len"
    fi
}
