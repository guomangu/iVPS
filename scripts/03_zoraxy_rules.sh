#!/usr/bin/env bash
# ==============================================================================
# 03_zoraxy_rules.sh - Pré-configuration automatique des règles de routage Zoraxy
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "${ROOT_DIR}/.env"

create_zoraxy_rule() {
    local domain="$1" target="$2" ws="$3" alias="${4:-}" pdir="$5"
    local alias_str="[]"
    [[ -n "$alias" ]] && alias_str="[\"${alias}\"]"
    cat <<EOF > "${pdir}/${domain}.config"
{
  "ProxyType": 1,
  "RootOrMatchingDomain": "${domain}",
  "MatchingDomainAlias": ${alias_str},
  "ActiveOrigins": [{
    "OriginIpOrDomain": "${target}",
    "RequireTLS": false,
    "SkipCertValidations": false,
    "SkipWebSocketOriginCheck": ${ws},
    "Weight": 1, "MaxConn": 0, "RespTimeout": 0
  }],
  "InactiveOrigins": [], "UseStickySession": false,
  "UseActiveLoadBalance": false, "Disabled": false,
  "BypassGlobalTLS": false, "VirtualDirectories": []
}
EOF
}

main() {
    local domain="${DOMAIN_NAME:-votre-domaine.com}"
    local admin_sub="${COCKPIT_SUBDOMAIN:-admin}"
    local proxy_sub="${ZORAXY_SUBDOMAIN:-proxy}"
    local sftp_sub="${SFTPGO_SUBDOMAIN:-folder}"
    local base="${DATA_DIR:-${ROOT_DIR}/data}"
    local conf_dir="${base}/zoraxy/config/conf"
    local proxy_dir="${conf_dir}/proxy"
    local html_dir="${base}/zoraxy/config/www/html"

    log_info "Configuration des règles de routage Zoraxy..."
    mkdir -p "$proxy_dir"
    [[ ! -f "${conf_dir}/version" ]] && echo -n "334" > "${conf_dir}/version"
    [[ "$domain" != "votre-domaine.com" ]] && rm -f "${proxy_dir}"/*votre-domaine.com*.config 2>/dev/null || true

    # Suppression de toute page d'accueil statique sur le domaine racine
    rm -f "${html_dir}/index.html" 2>/dev/null || true

    # Règles de sous-domaines (mode hôte: loopback 127.0.0.1)
    create_zoraxy_rule "${proxy_sub}.${domain}" "127.0.0.1:${ZORAXY_ADMIN_PORT:-8000}" false "" "$proxy_dir"
    create_zoraxy_rule "${admin_sub}.${domain}" "127.0.0.1:${COCKPIT_PORT:-9090}" true "" "$proxy_dir"
    create_zoraxy_rule "${sftp_sub}.${domain}" "127.0.0.1:${SFTPGO_WEB_PORT:-8080}" false "" "$proxy_dir"

    log_success "Règles Zoraxy créées : ${proxy_sub}.${domain}, ${admin_sub}.${domain}, ${sftp_sub}.${domain}."
}

main "$@"
