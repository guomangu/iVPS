#!/usr/bin/env bash
# ==============================================================================
# 01_install_deps.sh - Installation robuste et tolérante aux dépôts de l'OS
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

install_dnf_deps() {
    log_info "Installation des paquets sur Fedora / RHEL via DNF..."
    local core_pkgs=(podman podman-compose cockpit cockpit-podman cockpit-storaged curl iproute openssl firewalld)
    local opt_pkgs=(cockpit-packagekit pcp-zeroconf)

    if ! run_sudo dnf install -y --skip-unavailable "${core_pkgs[@]}" "${opt_pkgs[@]}"; then
        log_warn "Installation groupée échouée, basculement en mode granulaire..."
        for pkg in "${core_pkgs[@]}" "${opt_pkgs[@]}"; do
            run_sudo dnf install -y "$pkg" 2>/dev/null || log_warn "Paquet $pkg indisponible, ignoré."
        done
    fi
    run_sudo systemctl enable --now firewalld 2>/dev/null || true
}

install_apt_deps() {
    log_info "Mise à jour et installation des paquets APT (Debian/Ubuntu)..."
    run_sudo apt-get update -y
    local pkgs=(podman podman-compose cockpit cockpit-podman cockpit-storaged curl iproute2 openssl)
    for opt in cockpit-pcp cockpit-packagekit; do
        if apt-cache show "$opt" >/dev/null 2>&1; then pkgs+=("$opt"); fi
    done
    run_sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

install_pacman_deps() {
    log_info "Installation des paquets Pacman (Arch Linux)..."
    run_sudo pacman -Sy --noconfirm podman podman-compose cockpit cockpit-podman curl iproute2 openssl
}

are_core_deps_installed() {
    for cmd in podman curl ss openssl cockpit-bridge; do
        command -v "$cmd" >/dev/null 2>&1 || return 1
    done
    return 0
}

main() {
    log_info "=== Étape 1 : Vérification des dépendances système ==="
    if are_core_deps_installed; then
        log_info "Toutes les dépendances système requises sont déjà installées."
    else
        local pkg_mgr
        pkg_mgr=$(detect_pkg_mgr)
        case "$pkg_mgr" in
            dnf)    install_dnf_deps ;;\
            apt)    install_apt_deps ;;\
            pacman) install_pacman_deps ;;\
            *)      log_error "Gestionnaire '$pkg_mgr' non supporté." && exit 1 ;;
        esac
    fi

    for cmd in podman cockpit-bridge curl ss openssl; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_success "Outil vérifié : $cmd"
        else
            log_warn "Outil non disponible dans le PATH : $cmd"
        fi
    done
    log_success "Étape 1 validée."
}

main "$@"
