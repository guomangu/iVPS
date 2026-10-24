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
    systemctl --user stop ivps-stack.service 2>/dev/null || true
    systemctl --user disable ivps-stack.service 2>/dev/null || true
    rm -f "$service_file"
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user reset-failed 2>/dev/null || true
}

teardown_containers() {
    log_info "Arrêt et suppression des conteneurs Podman..."
    if [[ -f "${ROOT_DIR}/compose.yaml" ]]; then
        if command -v podman-compose >/dev/null 2>&1; then
            podman-compose -f "${ROOT_DIR}/compose.yaml" down 2>/dev/null || true
        elif command -v podman >/dev/null 2>&1; then
            podman compose -f "${ROOT_DIR}/compose.yaml" down 2>/dev/null || true
        fi
    fi
    if command -v podman >/dev/null 2>&1; then
        podman stop ivps-zoraxy ivps-pgadmin 2>/dev/null || true
        podman rm -f ivps-zoraxy ivps-sftpgo ivps-pgadmin 2>/dev/null || true
        local net="${PODMAN_NETWORK:-ivps-net}"
        if podman network exists "$net" 2>/dev/null; then
            podman network rm "$net" 2>/dev/null || true
            log_success "Réseau Podman '$net' supprimé."
        fi
    fi
}

remove_wireguard() {
    local unit="/etc/containers/systemd/ivps-wireguard.container"
    if [[ -e "$unit" ]]; then
        log_info "Arrêt et suppression du service WireGuard rootful..."
        run_sudo systemctl stop ivps-wireguard.service 2>/dev/null || true
        run_sudo rm -f "$unit"
        run_sudo systemctl daemon-reload 2>/dev/null || true
    fi
    run_sudo podman rm -f ivps-wireguard 2>/dev/null || true
    run_sudo rm -f /etc/sysctl.d/99-ivps-wireguard.conf \
        /etc/modules-load.d/ivps-wireguard.conf 2>/dev/null || true
    run_sudo sysctl --system >/dev/null 2>&1 || true
}

clean_configs() {
    local sysctl_conf="/etc/sysctl.d/99-ivps-ports.conf"
    if [[ -f "$sysctl_conf" ]]; then
        log_info "Nettoyage de la configuration sysctl..."
        run_sudo rm -f "$sysctl_conf"
        run_sudo sysctl --system >/dev/null 2>&1 || true
    fi

    local base="${DATA_DIR:-./data}"
    [[ "$base" = /* ]] || base="${ROOT_DIR}/${base#./}"
    if [[ "$PURGE_DATA" == "true" ]]; then
        log_warn "Suppression définitive des données persistantes ($base)..."
        run_sudo rm -rf "$base"
        log_success "Dossier de données supprimé."
    else
        log_info "Données conservées dans $base. Utilisez '--purge' pour les supprimer."
    fi
}

main() {
    log_warn "=== Désinstallation de la Stack IVPS ==="
    stop_user_service
    teardown_containers
    remove_wireguard
    clean_configs
    log_success "Désinstallation terminée avec succès."
}

main "$@"
