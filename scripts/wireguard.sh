#!/usr/bin/env bash
# ==============================================================================
# wireguard.sh - Chemins, migration et réglages hôte de wg-easy (sourcé)
# ==============================================================================
# Prérequis : common.sh sourcé et ROOT_DIR défini par l'appelant.

WG_LEGACY="${WG_LEGACY_DIR:-../reversevpn}"
[[ "$WG_LEGACY" = /* ]] || WG_LEGACY="${ROOT_DIR}/${WG_LEGACY#./}"
WG_DATA_ROOT="${DATA_DIR:-./data}"
[[ "$WG_DATA_ROOT" = /* ]] || WG_DATA_ROOT="${ROOT_DIR}/${WG_DATA_ROOT#./}"
WG_DATA_DIR="${WG_DATA_ROOT}/wireguard"
WG_ENV_FILE="${WG_DATA_DIR}/wg-easy.env"
WG_DB_FILE="${WG_DATA_DIR}/wg-easy.db"
WG_QUADLET_SRC="${ROOT_DIR}/containers/wireguard/wg-easy.container.in"
WG_QUADLET_DST="/etc/containers/systemd/ivps-wireguard.container"
WG_SERVICE="ivps-wireguard.service"

wg_legacy_env() {
    [[ -f "${WG_LEGACY}/.env" ]] || return 0
    grep -E "^$1=" "${WG_LEGACY}/.env" | tail -n1 | cut -d= -f2- || true
}

wg_detect_public_ip() {
    local url ip
    for url in https://api.ipify.org https://ifconfig.me/ip https://icanhazip.com; do
        ip=$(curl -fsS --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]' || true)
        [[ -n "$ip" ]] && { echo "$ip"; return 0; }
    done
}

wg_stop_legacy() {
    log_info "Désactivation de l'ancienne installation wg-easy (reversevpn)..."
    run_sudo systemctl stop wg-easy.service 2>/dev/null || true
    run_sudo systemctl disable wg-easy.service 2>/dev/null || true
    if [[ -e /etc/containers/systemd/wg-easy.container ]]; then
        run_sudo rm -f /etc/containers/systemd/wg-easy.container
        run_sudo systemctl daemon-reload
    fi
    run_sudo podman rm -f wg-easy 2>/dev/null || true
    run_sudo systemctl stop "$WG_SERVICE" 2>/dev/null || true
}

wg_migrate_data() {
    if ! run_sudo test -f "$WG_DB_FILE" 2>/dev/null && \
        [[ -f "${WG_LEGACY}/data/wg-easy.db" ]]; then
        log_info "Migration des clés et de la base depuis ${WG_LEGACY}/data..."
        run_sudo mkdir -p "$WG_DATA_DIR"
        run_sudo cp -a "${WG_LEGACY}/data/." "$WG_DATA_DIR/"
    fi
    run_sudo mkdir -p "$WG_DATA_DIR"
    run_sudo chmod 700 "$WG_DATA_DIR"
    run_sudo chown -R root:root "$WG_DATA_DIR" 2>/dev/null || true
}

wg_resolve_settings() {
    local free
    if is_port_in_use "${WG_UI_PORT:-9999}"; then
        free=$(find_free_port "${WG_UI_PORT:-9999}")
        log_warn "Port ${WG_UI_PORT:-9999} occupé : UI wg-easy déplacée sur ${free}."
        update_env_var WG_UI_PORT "$free" "$ENV_FILE"
    fi
    [[ -n "${WG_INIT_HOST:-}" ]] || WG_INIT_HOST=$(wg_legacy_env INIT_HOST)
    [[ -n "${WG_INIT_HOST:-}" ]] || WG_INIT_HOST=$(wg_detect_public_ip)
    WG_INIT_USERNAME="${WG_INIT_USERNAME:-$(wg_legacy_env INIT_USERNAME)}"
    WG_INIT_USERNAME="${WG_INIT_USERNAME:-${ADMIN_USER:-admin}}"
    WG_INIT_PASSWORD="${WG_INIT_PASSWORD:-$(wg_legacy_env INIT_PASSWORD)}"
    WG_INIT_PASSWORD="${WG_INIT_PASSWORD:-${ADMIN_PASSWORD:-}}"
    if [[ -z "$WG_INIT_PASSWORD" ]]; then
        WG_INIT_PASSWORD=$(generate_password 20)
        update_env_var WG_INIT_PASSWORD "$WG_INIT_PASSWORD" "$ENV_FILE"
    fi
}

wg_install_kernel() {
    run_sudo install -m 644 "${ROOT_DIR}/config/modules-load/ivps-wireguard.conf" \
        /etc/modules-load.d/ivps-wireguard.conf
    run_sudo modprobe wireguard 2>/dev/null || log_warn "modprobe wireguard indisponible."
    run_sudo install -m 644 "${ROOT_DIR}/config/sysctl/99-ivps-wireguard.conf" \
        /etc/sysctl.d/99-ivps-wireguard.conf
    run_sudo sysctl --system >/dev/null 2>&1 || true
}
