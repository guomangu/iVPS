#!/usr/bin/env bash
# ==============================================================================
# 03_configure.sh - Configuration des services Cockpit et pré-réglages Zoraxy
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "${ROOT_DIR}/.env"

configure_cockpit() {
    local domain="${DOMAIN_NAME:-votre-domaine.com}"
    local sub="${COCKPIT_SUBDOMAIN:-admin}"
    local cockpit_dir="/etc/cockpit"
    local cockpit_conf="${cockpit_dir}/cockpit.conf"

    log_info "Configuration de Cockpit pour le Reverse Proxy Zoraxy..."
    run_sudo mkdir -p "$cockpit_dir"

    # Génération sécurisée de cockpit.conf pour accepter les requêtes proxy et websockets
    run_sudo tee "$cockpit_conf" >/dev/null <<EOF
[WebService]
Origins = https://${sub}.${domain} wss://${sub}.${domain} http://localhost:${COCKPIT_PORT:-9090}
ProtocolHeader = X-Forwarded-Proto
ForwardedForHeader = X-Forwarded-For
AllowUnencrypted = true
EOF
    log_success "Fichier $cockpit_conf mis à jour."

    # Redémarrage du socket cockpit pour prise en compte
    log_info "Activation du socket systemd Cockpit..."
    run_sudo systemctl daemon-reload
    run_sudo systemctl enable --now cockpit.socket
    log_success "Cockpit socket actif et en écoute."
}

configure_firewall() {
    # Ouverture des ports firewall standard si ufw ou firewalld est actif
    if command -v ufw >/dev/null 2>&1 && run_sudo ufw status | grep -qw "active"; then
        log_info "Configuration du pare-feu UFW..."
        run_sudo ufw allow 80/tcp comment 'Zoraxy HTTP' || true
        run_sudo ufw allow 443/tcp comment 'Zoraxy HTTPS' || true
        run_sudo ufw allow "${SFTPGO_SFTP_PORT:-2022}"/tcp comment 'SFTPGo SFTP' || true
        run_sudo ufw allow "${ZORAXY_ADMIN_PORT:-8000}"/tcp comment 'Zoraxy Admin Setup' || true
        log_success "Règles UFW appliquées."
    fi
}

main() {
    log_info "=== Étape 3 : Configuration des composants ==="
    configure_cockpit
    configure_firewall
    log_success "Étape 3 terminée avec succès."
}

main "$@"
