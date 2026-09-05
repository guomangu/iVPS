#!/usr/bin/env bash
# ==============================================================================
# 01_install_deps.sh - Installation des dépendances avec support Fedora complet
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

install_dnf_deps() {
    log_info "Installation des paquets sur Fedora / RHEL via DNF..."
    local pkgs=(
        podman podman-compose cockpit cockpit-podman
        cockpit-storaged cockpit-pcp cockpit-packagekit
        curl iproute openssl firewalld
    )
    run_sudo dnf install -y "${pkgs[@]}"
    # Assurer que firewalld est actif
    run_sudo systemctl enable --now firewalld || true
}

install_apt_deps() {
    log_info "Mise à jour et installation des paquets APT (Debian/Ubuntu)..."
    run_sudo apt-get update -y
    local pkgs=(podman podman-compose cockpit cockpit-podman cockpit-storaged cockpit-pcp curl iproute2 openssl)
    if apt-cache show cockpit-packagekit >/dev/null 2>&1; then
        pkgs+=(cockpit-packagekit)
    fi
    run_sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

install_pacman_deps() {
    log_info "Installation des paquets Pacman (Arch Linux)..."
    run_sudo pacman -Sy --noconfirm podman podman-compose cockpit cockpit-podman curl iproute2 openssl
}

main() {
    log_info "=== Étape 1 : Vérification des dépendances système ==="
    local pkg_mgr
    pkg_mgr=$(detect_pkg_mgr)

    case "$pkg_mgr" in
        dnf)    install_dnf_deps ;;
        apt)    install_apt_deps ;;
        pacman) install_pacman_deps ;;
        *)
            log_error "Gestionnaire de paquets '$pkg_mgr' non supporté." && exit 1
            ;;
    esac

    for cmd in podman cockpit-bridge curl ss openssl; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_success "Outil vérifié : $cmd"
        else
            log_warn "Outil non trouvé dans le PATH : $cmd"
        fi
    done
    log_success "Étape 1 validée."
}

main "$@"
