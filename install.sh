#!/usr/bin/env bash
# ==============================================================================
# install.sh - Orchestrateur d'installation de la Stack VPS (Zoraxy/Cockpit/SFTPGo)
# ==============================================================================
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${PROJECT_DIR}/scripts/common.sh"

init_env() {
    if [[ ! -f "${PROJECT_DIR}/.env" ]]; then
        log_warn "Aucun fichier .env trouvé. Initialisation depuis .env.example..."
        cp "${PROJECT_DIR}/.env.example" "${PROJECT_DIR}/.env"
        log_success "Fichier .env initialisé. Vous pouvez l'éditer pour personnaliser votre domaine."
    fi
    load_env "${PROJECT_DIR}/.env"
}

print_summary() {
    local domain="${DOMAIN_NAME:-votre-domaine.com}"
    echo -e "\n${C_GREEN}================================================================${C_RESET}"
    echo -e "${C_GREEN}          INSTALLATION DE LA STACK IVPS TERMINÉE AVEC SUCCÈS    ${C_RESET}"
    echo -e "${C_GREEN}================================================================${C_RESET}"
    echo -e "${C_CYAN}Point d'accès aux services :${C_RESET}"
    echo -e "  - Zoraxy Initial Setup : ${C_YELLOW}http://<IP-SERVEUR>:${ZORAXY_ADMIN_PORT:-8000}${C_RESET}"
    echo -e "  - Cockpit Web Console  : ${C_YELLOW}https://${COCKPIT_SUBDOMAIN:-admin}.${domain}${C_RESET} (Direct : port ${COCKPIT_PORT:-9090})"
    echo -e "  - SFTPGo Web Client    : ${C_YELLOW}https://${SFTPGO_SUBDOMAIN:-fichiers}.${domain}${C_RESET} (Direct : port ${SFTPGO_WEB_PORT:-8080})"
    echo -e "  - SFTP Accès Fichiers  : ${C_YELLOW}sftp://<user>@<IP-SERVEUR>:${SFTPGO_SFTP_PORT:-2022}${C_RESET}"
    echo -e "\n${C_CYAN}Commandes utiles :${C_RESET}"
    echo -e "  - État des services   : ${C_YELLOW}systemctl --user status ivps-stack.service${C_RESET}"
    echo -e "  - Logs en temps réel  : ${C_YELLOW}journalctl --user -u ivps-stack.service -f${C_RESET}"
    echo -e "  - Désinstaller        : ${C_YELLOW}./uninstall.sh${C_RESET}"
    echo -e "${C_GREEN}================================================================${C_RESET}\n"
}

main() {
    log_info "Démarrage de l'installation automatisée de la stack IVPS..."
    init_env

    # Exécution séquentielle des étapes d'installation
    bash "${PROJECT_DIR}/scripts/01_install_deps.sh"
    bash "${PROJECT_DIR}/scripts/02_install_components.sh"
    bash "${PROJECT_DIR}/scripts/03_configure.sh"
    bash "${PROJECT_DIR}/scripts/04_systemd_linger.sh"

    print_summary
}

main "$@"
