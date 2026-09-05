#!/usr/bin/env bash
# ==============================================================================
# 01_install_deps.sh - Installation idempotente des dépendances du système
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

install_apt_deps() {
    log_info "Mise à jour des dépôts APT..."
    run_sudo apt-get update -y
    local pkgs=(podman podman-compose cockpit cockpit-podman cockpit-storaged cockpit-pcp curl)
    # cockpit-packagekit n'est pas disponible sur toutes les architectures/versions
    if apt-cache show cockpit-packagekit >/dev/null 2>&1; then
        pkgs+=(cockpit-packagekit)
    fi
    log_info "Installation des paquets APT : ${pkgs[*]}"
    run_sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

install_dnf_deps() {
    log_info "Installation des paquets DNF..."
    local pkgs=(podman podman-compose cockpit cockpit-podman cockpit-storaged cockpit-pcp cockpit-packagekit curl)
    run_sudo dnf install -y "${pkgs[@]}"
}

install_pacman_deps() {
    log_info "Installation des paquets Pacman..."
    run_sudo pacman -Sy --noconfirm podman podman-compose cockpit cockpit-podman curl
}

main() {
    log_info "=== Étape 1 : Vérification et installation des dépendances ==="
    local pkg_mgr
    pkg_mgr=$(detect_pkg_mgr)

    case "$pkg_mgr" in
        apt)    install_apt_deps ;;
        dnf)    install_dnf_deps ;;
        pacman) install_pacman_deps ;;
        *)
            log_error "Gestionnaire de paquets '$pkg_mgr' non supporté pour l'installation auto."
            exit 1
            ;;
    esac

    # Vérification de présence des commandes critiques
    for cmd in podman cockpit-bridge curl; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_success "Commande trouvée : $cmd"
        else
            log_warn "Commande optionnelle absente : $cmd"
        fi
    done
    log_success "Étape 1 terminée avec succès."
}

main "$@"
