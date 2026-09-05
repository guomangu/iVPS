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
for arg in "$@"; do
    [[ "$arg" == "--purge" ]] && PURGE_DATA=true
done

stop_user_service() {
    local service_file="${HOME}/.config/systemd/user/ivps-stack.service"
    log_info "Arrêt et désactivation du service systemd utilisateur..."
    if systemctl --user list-unit-files 2>/dev/null | grep -qw "ivps-stack.service"; then
        systemctl --user stop ivps-stack.service 2>/dev/null || true
        systemctl --user disable ivps-stack.service 2>/dev/null || true
        rm -f "$service_file"
        systemctl --user daemon-reload
        log_success "Service systemd ivps-stack supprimé."
    fi
}

teardown_containers() {
    log_info "Arrêt et suppression des conteneurs Podman..."
    if command -v podman >/dev/null 2>&1; then
        podman rm -f ivps-zoraxy ivps-sftpgo 2>/dev/null || true
        local net="${PODMAN_NETWORK:-ivps-net}"
        if podman network exists "$net" 2>/dev/null; then
            podman network rm "$net" 2>/dev/null || true
            log_success "Réseau Podman '$net' supprimé."
        fi
    fi
}

clean_configs() {
    local sysctl_conf="/etc/sysctl.d/99-ivps-ports.conf"
    if [[ -f "$sysctl_conf" ]]; then
        log_info "Nettoyage de la configuration sysctl..."
        run_sudo rm -f "$sysctl_conf"
        run_sudo sysctl --system >/dev/null 2>&1 || true
    fi

    local base="${DATA_DIR:-${ROOT_DIR}/data}"
    if [[ "$PURGE_DATA" == "true" ]]; then
        log_warn "Suppression définitive des données persistantes ($base)..."
        rm -rf "$base"
        log_success "Dossier de données supprimé."
    else
        log_info "Données conservées dans $base. Utilisez '--purge' pour les supprimer."
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
