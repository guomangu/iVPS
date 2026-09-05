#!/usr/bin/env bash
# ==============================================================================
# 03_configure.sh - Configuration Cockpit, origines proxy et pare-feu
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
Origins = https://${admin_sub}.${domain} wss://${admin_sub}.${domain} https://${proxy_sub}.${domain} https://${domain} wss://${domain} http://localhost:${COCKPIT_PORT:-9090} http://127.0.0.1:${COCKPIT_PORT:-9090}
ProtocolHeader = X-Forwarded-Proto
ForwardedForHeader = X-Forwarded-For
AllowUnencrypted = true
EOF
    run_sudo systemctl daemon-reload
    run_sudo systemctl enable --now cockpit.socket
    log_success "Fichier $conf_file configuré."
}

configure_firewall() {
    local sftp_p="${SFTPGO_SFTP_PORT:-2022}"
    local zoraxy_p="${ZORAXY_ADMIN_PORT:-8000}"

    if command -v firewall-cmd >/dev/null 2>&1; then
        run_sudo systemctl start firewalld 2>/dev/null || true
        if run_sudo firewall-cmd --state >/dev/null 2>&1; then
            log_info "Configuration du pare-feu Firewalld (Fedora / RHEL)..."
            for p in cockpit 80/tcp 443/tcp "${sftp_p}/tcp" "${zoraxy_p}/tcp"; do
                run_sudo firewall-cmd --permanent --add-port="$p" 2>/dev/null || \
                run_sudo firewall-cmd --permanent --add-service="$p" 2>/dev/null || true
            done
            run_sudo firewall-cmd --reload || true
            log_success "Règles Firewalld appliquées."
        fi
    elif command -v ufw >/dev/null 2>&1 && run_sudo ufw status | grep -qw "active"; then
        log_info "Configuration du pare-feu UFW..."
        for p in 80/tcp 443/tcp "${sftp_p}/tcp" "${zoraxy_p}/tcp" "${COCKPIT_PORT:-9090}/tcp"; do
            run_sudo ufw allow "$p" || true
        done
        log_success "Règles UFW appliquées."
    fi
}

main() {
    log_info "=== Étape 3 : Configuration système, Cockpit, Pare-feu et Zoraxy ==="
    configure_cockpit
    configure_firewall
    bash "${SCRIPT_DIR}/03_zoraxy_rules.sh"
    log_success "Étape 3 terminée avec succès."
}

main "$@"
