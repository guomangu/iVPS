#!/usr/bin/env bash
# ==============================================================================
# 03_configure.sh - Configuration Cockpit, origines proxy et pare-feu (Firewalld/UFW)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "${ROOT_DIR}/.env"

configure_cockpit() {
    local domain="${DOMAIN_NAME:-votre-domaine.com}"
    local admin_sub="${COCKPIT_SUBDOMAIN:-admin}"
    local proxy_sub="${ZORAXY_SUBDOMAIN:-proxy}"
    local conf_dir="/etc/cockpit"
    local conf_file="${conf_dir}/cockpit.conf"

    log_info "Configuration de Cockpit pour le Reverse Proxy Zoraxy..."
    run_sudo mkdir -p "$conf_dir"

    run_sudo tee "$conf_file" >/dev/null <<EOF
[WebService]
Origins = https://${admin_sub}.${domain} wss://${admin_sub}.${domain} https://${proxy_sub}.${domain} http://localhost:${COCKPIT_PORT:-9090} http://127.0.0.1:${COCKPIT_PORT:-9090}
ProtocolHeader = X-Forwarded-Proto
ForwardedForHeader = X-Forwarded-For
AllowUnencrypted = true
EOF
    log_success "Fichier $conf_file configuré."
    run_sudo systemctl daemon-reload
    run_sudo systemctl enable --now cockpit.socket
    log_success "Socket Cockpit activé."
}

configure_firewall() {
    local sftp_p="${SFTPGO_SFTP_PORT:-2022}"
    local zoraxy_p="${ZORAXY_ADMIN_PORT:-8000}"

    if command -v firewall-cmd >/dev/null 2>&1; then
        run_sudo systemctl start firewalld 2>/dev/null || true
        if run_sudo firewall-cmd --state >/dev/null 2>&1; then
            log_info "Configuration du pare-feu Firewalld (Fedora / RHEL)..."
            run_sudo firewall-cmd --permanent --add-service=cockpit || true
            run_sudo firewall-cmd --permanent --add-port=80/tcp || true
            run_sudo firewall-cmd --permanent --add-port=443/tcp || true
            run_sudo firewall-cmd --permanent --add-port="${sftp_p}/tcp" || true
            run_sudo firewall-cmd --permanent --add-port="${zoraxy_p}/tcp" || true
            run_sudo firewall-cmd --reload || true
            log_success "Règles Firewalld appliquées."
        fi
    elif command -v ufw >/dev/null 2>&1 && run_sudo ufw status | grep -qw "active"; then
        log_info "Configuration du pare-feu UFW..."
        run_sudo ufw allow 80/tcp comment 'HTTP' || true
        run_sudo ufw allow 443/tcp comment 'HTTPS' || true
        run_sudo ufw allow "${sftp_p}"/tcp comment 'SFTP' || true
        run_sudo ufw allow "${zoraxy_p}"/tcp comment 'Zoraxy Admin' || true
        run_sudo ufw allow "${COCKPIT_PORT:-9090}"/tcp comment 'Cockpit' || true
        log_success "Règles UFW appliquées."
    fi
}

main() {
    log_info "=== Étape 3 : Configuration de Cockpit et du Pare-feu ==="
    configure_cockpit
    configure_firewall
    log_success "Étape 3 terminée avec succès."
}

main "$@"
