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

setup_landing_page() {
    local html_dir="$1" domain="$2" admin_sub="$3" sftp_sub="$4" proxy_sub="$5"
    mkdir -p "$html_dir"
    cat <<EOF > "${html_dir}/index.html"
<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Stack IVPS - ${domain}</title>
<style>body{font-family:system-ui,-apple-system,sans-serif;background:#090d16;color:#f1f5f9;margin:0;display:flex;align-items:center;justify-content:center;min-height:100vh;}
.c{background:#131d31;padding:2.5rem;border-radius:16px;max-width:440px;width:90%;border:1px solid #1e293b;box-shadow:0 10px 30px rgba(0,0,0,0.5);text-align:center;}
h1{color:#38bdf8;font-size:1.6rem;margin-top:0;}p{color:#94a3b8;font-size:0.95rem;margin-bottom:2rem;}
.b{display:block;padding:12px;margin-bottom:10px;border-radius:8px;font-weight:600;text-decoration:none;transition:0.2s;}
.b1{background:#0284c7;color:#fff;}.b1:hover{background:#0369a1;}
.b2{background:#1e293b;color:#cbd5e1;border:1px solid #334155;}.b2:hover{background:#334155;}
</style></head><body><div class="c"><h1>Stack IVPS</h1><p>${domain}</p>
<a class="b b1" href="https://${admin_sub}.${domain}">Cockpit Console OS</a>
<a class="b b2" href="https://${sftp_sub}.${domain}">SFTPGo Fichiers</a>
<a class="b b2" href="https://${proxy_sub}.${domain}">Zoraxy Reverse Proxy</a>
</div></body></html>
EOF
}

main() {
    local domain="${DOMAIN_NAME:-votre-domaine.com}"
    local admin_sub="${COCKPIT_SUBDOMAIN:-admin}"
    local proxy_sub="${ZORAXY_SUBDOMAIN:-proxy}"
    local sftp_sub="${SFTPGO_SUBDOMAIN:-fichiers}"
    local base="${DATA_DIR:-${ROOT_DIR}/data}"
    local conf_dir="${base}/zoraxy/config/conf"
    local proxy_dir="${conf_dir}/proxy"
    local html_dir="${base}/zoraxy/config/www/html"

    log_info "Configuration des règles de routage Zoraxy..."
    mkdir -p "$proxy_dir"
    [[ ! -f "${conf_dir}/version" ]] && echo -n "334" > "${conf_dir}/version"
    [[ "$domain" != "votre-domaine.com" ]] && rm -f "${proxy_dir}"/*votre-domaine.com*.config 2>/dev/null || true

    create_zoraxy_rule "${proxy_sub}.${domain}" "127.0.0.1:8000" false "" "$proxy_dir"
    create_zoraxy_rule "${admin_sub}.${domain}" "host.containers.internal:${COCKPIT_PORT:-9090}" true "${domain}" "$proxy_dir"
    create_zoraxy_rule "${sftp_sub}.${domain}" "ivps-sftpgo:8080" false "" "$proxy_dir"
    setup_landing_page "$html_dir" "$domain" "$admin_sub" "$sftp_sub" "$proxy_sub"

    log_success "Règles Zoraxy créées : ${proxy_sub}.${domain}, ${admin_sub}.${domain} (+${domain}), ${sftp_sub}.${domain}."
}

main "$@"
