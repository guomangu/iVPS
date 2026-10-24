#!/usr/bin/env bash
# ==============================================================================
# 02_install_wireguard.sh - wg-easy rootful, migration reversevpn et Quadlet
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "${ENV_FILE}"
# shellcheck source=scripts/wireguard.sh
source "${SCRIPT_DIR}/wireguard.sh"
# shellcheck source=scripts/wireguard_quadlet.sh
source "${SCRIPT_DIR}/wireguard_quadlet.sh"

main() {
    if [[ "${WG_ENABLED:-true}" != "true" ]]; then
        log_info "WireGuard désactivé (WG_ENABLED=false), étape ignorée."
        return 0
    fi
    log_info "=== Étape 2b : WireGuard (wg-easy rootful) ==="
    run_sudo podman info >/dev/null 2>&1 || {
        log_error "Podman rootful indisponible."
        exit 1
    }
    wg_stop_legacy
    wg_migrate_data
    wg_resolve_settings
    wg_install_kernel
    wg_write_env
    wg_install_quadlet
    run_sudo podman pull "${WG_IMAGE:-ghcr.io/wg-easy/wg-easy:15}" >/dev/null
    run_sudo systemctl restart "$WG_SERVICE"
    if systemctl is-active --quiet "$WG_SERVICE"; then
        log_success "WireGuard actif (UI ${WG_UI_BIND:-127.0.0.1}:${WG_UI_PORT:-9999})."
    else
        log_warn "Service inactif : journalctl -u $WG_SERVICE -n 50"
    fi
}

main "$@"
