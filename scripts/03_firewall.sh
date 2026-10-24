#!/usr/bin/env bash
# ==============================================================================
# 03_firewall.sh - Ouverture des ports web, WireGuard et interfaces d'admin
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "${ROOT_DIR}/.env"

build_port_list() {
    local ports=("cockpit" "80/tcp" "443/tcp" "${ZORAXY_ADMIN_PORT:-8000}/tcp")
    if [[ "${WG_ENABLED:-true}" == "true" ]]; then
        ports+=("${WG_LISTEN_PORT:-51820}/udp")
        if ! wg_ui_is_private; then
            ports+=("${WG_UI_PORT:-9999}/tcp")
        fi
    fi
    printf '%s\n' "${ports[@]}"
}

wg_ui_is_private() {
    [[ "${WG_UI_BIND:-127.0.0.1}" == "127.0.0.1" || \
       "${WG_UI_BIND:-127.0.0.1}" == "localhost" ]]
}

remove_legacy_private_ui_port() {
    [[ "${WG_ENABLED:-true}" == "true" ]] || return 0
    wg_ui_is_private || return 0
    run_sudo firewall-cmd --permanent --remove-port="${WG_UI_PORT:-9999}/tcp" \
        >/dev/null 2>&1 || true
}

configure_firewalld() {
    local p
    run_sudo systemctl start firewalld 2>/dev/null || true
    run_sudo firewall-cmd --state >/dev/null 2>&1 || return 0
    log_info "Configuration du pare-feu Firewalld (Fedora / RHEL)..."
    while read -r p; do
        run_sudo firewall-cmd --permanent --add-port="$p" 2>/dev/null || \
            run_sudo firewall-cmd --permanent --add-service="$p" 2>/dev/null || true
    done < <(build_port_list)
    remove_legacy_private_ui_port
    run_sudo firewall-cmd --reload || true
    log_success "Règles Firewalld appliquées."
}

configure_ufw() {
    local p
    log_info "Configuration du pare-feu UFW..."
    while read -r p; do
        [[ "$p" == "cockpit" ]] && p="${COCKPIT_PORT:-9090}/tcp"
        run_sudo ufw allow "$p" || true
    done < <(build_port_list)
    if [[ "${WG_ENABLED:-true}" == "true" ]] && wg_ui_is_private; then
        run_sudo ufw delete allow "${WG_UI_PORT:-9999}/tcp" >/dev/null 2>&1 || true
    fi
    log_success "Règles UFW appliquées."
}

main() {
    if command -v firewall-cmd >/dev/null 2>&1; then
        configure_firewalld
    elif command -v ufw >/dev/null 2>&1 && run_sudo ufw status | grep -qw "active"; then
        configure_ufw
    else
        log_warn "Aucun pare-feu actif détecté (Firewalld/UFW)."
    fi
}

main "$@"
