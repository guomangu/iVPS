#!/usr/bin/env bash
# ==============================================================================
# 02_install_components.sh - Préparation du stockage, réseau et images Podman
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "${ROOT_DIR}/.env"

setup_storage() {
    log_info "Création des répertoires de données persistantes..."
    local base="${DATA_DIR:-${ROOT_DIR}/data}"
    local dirs=(
        "${base}/zoraxy/config"
        "${base}/zoraxy/plugin"
        "${base}/sftpgo/data"
        "${base}/sftpgo/srv"
    )
    for d in "${dirs[@]}"; do
        if [[ ! -d "$d" ]]; then
            mkdir -p "$d"
            log_info "Répertoire créé : $d"
        fi
    done
    # Permissions pour SFTPGo (UID standard 1000 dans le conteneur)
    chmod -R 750 "$base"
}

setup_unprivileged_ports() {
    if [[ "${ENABLE_UNPRIVILEGED_PORTS:-true}" == "true" ]]; then
        log_info "Configuration des ports non privilégiés (ports 80 & 443)..."
        local sysctl_conf="/etc/sysctl.d/99-ivps-ports.conf"
        if [[ ! -f "$sysctl_conf" ]]; then
            echo "net.ipv4.ip_unprivileged_port_start=80" | run_sudo tee "$sysctl_conf" >/dev/null
            run_sudo sysctl --system >/dev/null
            log_success "Ports non privilégiés configurés sur 80."
        fi
    fi
}

setup_podman_network() {
    local net="${PODMAN_NETWORK:-ivps-net}"
    if podman network exists "$net" 2>/dev/null; then
        log_info "Le réseau Podman '$net' existe déjà."
    else
        log_info "Création du réseau Podman '$net'..."
        podman network create "$net"
        log_success "Réseau '$net' créé."
    fi
}

pull_images() {
    log_info "Téléchargement des images Podman..."
    podman pull "${ZORAXY_IMAGE:-zoraxydocker/zoraxy:latest}"
    podman pull "${SFTPGO_IMAGE:-drakkan/sftpgo:latest}"
    log_success "Images Podman téléchargées avec succès."
}

main() {
    log_info "=== Étape 2 : Préparation des composants centraux ==="
    setup_storage
    setup_unprivileged_ports
    setup_podman_network
    pull_images
    log_success "Étape 2 terminée avec succès."
}

main "$@"
