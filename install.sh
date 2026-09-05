#!/usr/bin/env bash
# ==============================================================================
# install.sh - Orchestrateur d'installation et synchronisation de la Stack IVPS
# ==============================================================================
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${PROJECT_DIR}/scripts/common.sh"

init_env() {
    if [[ ! -f "${PROJECT_DIR}/.env" ]]; then
        log_warn "Fichier .env absent. Initialisation depuis .env.example..."
        cp "${PROJECT_DIR}/.env.example" "${PROJECT_DIR}/.env"
        log_success "Fichier .env créé."
    fi
}

stop_active_stack() {
    if systemctl --user is-active --quiet ivps-stack.service 2>/dev/null; then
        log_info "Synchronisation : arrêt temporaire de la stack active..."
        systemctl --user stop ivps-stack.service 2>/dev/null || true
    fi
}

print_summary() {
    load_env "${PROJECT_DIR}/.env"
    local domain="${DOMAIN_NAME:-votre-domaine.com}"
    local user="${ADMIN_USER:-admin}"
    echo -e "\n${C_GREEN}================================================================${C_RESET}"
    echo -e "${C_GREEN}          STACK IVPS DÉPLOYÉE ET OPÉRATIONNELLE                 ${C_RESET}"
    echo -e "${C_GREEN}================================================================${C_RESET}"
    echo -e "${C_CYAN}Identifiants Centraux d'Administration :${C_RESET}"
    echo -e "  - Utilisateur unifié    : ${C_YELLOW}${user}${C_RESET}"
    echo -e "  - Mot de passe maître   : ${C_YELLOW}${ADMIN_PASSWORD}${C_RESET}"
    echo -e "    ${C_RESET}(Personnalisable dans .env, rejouez ./install.sh pour l'appliquer)"
    echo -e "\n${C_CYAN}Points d'accès aux services :${C_RESET}"
    echo -e "  - Zoraxy Web Admin    : ${C_YELLOW}https://${ZORAXY_SUBDOMAIN:-proxy}.${domain}${C_RESET} (Direct : port ${ZORAXY_ADMIN_PORT:-8000})"
    echo -e "  - Cockpit Console OS  : ${C_YELLOW}https://${COCKPIT_SUBDOMAIN:-admin}.${domain}${C_RESET} (Direct : port ${COCKPIT_PORT:-9090})"
    echo -e "  - SFTPGo Web Client   : ${C_YELLOW}https://${SFTPGO_SUBDOMAIN:-folder}.${domain}${C_RESET} (Direct : port ${SFTPGO_WEB_PORT:-8080})"
    echo -e "  - SFTP Serveur Fichiers: ${C_YELLOW}sftp://${user}@<IP-SERVEUR>:${SFTPGO_SFTP_PORT:-2022}${C_RESET}"
    echo -e "\n${C_CYAN}Commandes d'exploitation :${C_RESET}"
    echo -e "  - Statut de la stack   : ${C_YELLOW}systemctl --user status ivps-stack.service${C_RESET}"
    echo -e "  - Journaux en direct   : ${C_YELLOW}journalctl --user -u ivps-stack.service -f${C_RESET}"
    echo -e "  - Réappliquer les modifs: ${C_YELLOW}./install.sh${C_RESET}"
    echo -e "  - Désinstaller         : ${C_YELLOW}./uninstall.sh${C_RESET}"
    echo -e "${C_GREEN}================================================================${C_RESET}\n"
}

main() {
    log_info "Lancement du déploiement / synchronisation de la stack IVPS..."
    init_env
    stop_active_stack
    bash "${PROJECT_DIR}/scripts/01_install_deps.sh"
    bash "${PROJECT_DIR}/scripts/02_install_components.sh"
    bash "${PROJECT_DIR}/scripts/03_configure.sh"
    bash "${PROJECT_DIR}/scripts/04_systemd_linger.sh"
    bash "${PROJECT_DIR}/scripts/05_init_auth.sh"
    print_summary
}

main "$@"
