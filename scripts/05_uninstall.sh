#!/usr/bin/env bash
# ==============================================================================
# 05_uninstall.sh - Désinstallation propre et sécurisée de la stack IVPS
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "${ROOT_DIR}/.env"

PURGE_DATA=false
[[ "${1:-}" == "--purge" ]] && PURGE_DATA=true

stop_user_service() {
    local service_file="${HOME}/.config/systemd/user/ivps-stack.service"
    log_info "Arrêt et désactivation du service systemd utilisateur..."
    if systemctl --user list-unit-files | grep -qw "ivps-stack.service"; then
        systemctl --user stop ivps-stack.service || true
        systemctl --user disable ivps-stack.service || true
        rm -f "$service_file"
        systemctl --user daemon-reload
        log_success "Service systemd ivps-stack supprimé."
    fi
}

teardown_containers() {
    log_info "Arrêt des conteneurs Podman..."
    if command -v podman >/dev/null 2>&1; then
        podman rm -f ivps-zoraxy ivps-sftpgo 2>/dev/null || true
        local net="${PODMAN_NETWORK:-ivps-net}"
        if podman network exists "$net" 2>/dev/null; then
            podman network rm "$net" || true
            log_success "Réseau Podman '$net' supprimé."
        fi
    fi
}

clean_configs() {
    local sysctl_conf="/etc/sysctl.d/99-ivps-ports.conf"
    if [[ -f "$sysctl_conf" ]]; then
        log_info "Nettoyage du réglage sysctl ports..."
        run_sudo rm -f "$sysctl_conf"
        run_sudo sysctl --system >/dev/null 2>&1 || true
    fi

    if [[ "$PURGE_DATA" == "true" ]]; then
        local base="${DATA_DIR:-${ROOT_DIR}/data}"
        log_warn "Suppression définitive des données persistantes ($base)..."
        rm -rf "$base"
        log_success "Données supprimées."
    else
        log_info "Données conservées dans ${DATA_DIR:-${ROOT_DIR}/data}. Utilisez '--purge' pour tout effacer."
    fi
}

main() {
    log_warn "=== Désinstallation de la Stack IVPS ==="
    stop_user_service
    teardown_containers
    clean_configs
    log_success "Désinstallation terminée avec succès."
}

main "$@"
