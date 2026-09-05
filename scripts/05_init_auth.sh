#!/usr/bin/env bash
# ==============================================================================
# 05_init_auth.sh - Initialisation et synchronisation des accès Zoraxy et SFTPGo
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "${ROOT_DIR}/.env"

wait_for_http() {
    local url="$1" max_retries="${2:-25}"
    for ((i = 1; i <= max_retries; i++)); do
        curl -s -L -f -o /dev/null "$url" 2>/dev/null && return 0
        sleep 1
    done
    return 1
}

init_zoraxy_admin() {
    local port="${ZORAXY_ADMIN_PORT:-8000}" pass="${ADMIN_PASSWORD}"
    local user="${ADMIN_USER:-admin}" base="http://127.0.0.1:${port}"
    local cookie_jar html csrf count
    cookie_jar=$(mktemp)

    log_info "Attente du démarrage de Zoraxy sur le port $port..."
    if ! wait_for_http "${base}/login.html" 25; then
        log_warn "Zoraxy n'a pas répondu à temps." && rm -f "$cookie_jar" && return 0
    fi

    html=$(curl -s -c "$cookie_jar" "${base}/login.html")
    csrf=$(echo "$html" | grep -o 'name="zoraxy\.csrf\.Token" content="[^"]*"' | sed -E 's/.*content="([^"]+)".*/\1/' || true)
    count=$(curl -s -b "$cookie_jar" "${base}/api/auth/userCount" 2>/dev/null || echo "1")

    if [[ "$count" == "0" && -n "$csrf" ]]; then
        log_info "Initialisation administrateur Zoraxy ('$user')..."
        curl -s -b "$cookie_jar" -H "X-CSRF-Token: $csrf" \
            -d "username=${user}&password=${pass}" "${base}/api/auth/register" >/dev/null
        log_success "Compte administrateur Zoraxy '$user' initialisé."
    else
        log_info "Compte administrateur Zoraxy déjà provisionné."
    fi
    rm -f "$cookie_jar"
}

get_sftpgo_token() {
    local base="$1" user="$2" pass="$3" resp tok
    resp=$(curl -s -u "${user}:${pass}" "${base}/api/v2/token" 2>/dev/null || true)
    tok=$(echo "$resp" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 || true)
    if [[ -z "$tok" && "$user" != "admin" ]]; then
        resp=$(curl -s -u "admin:${pass}" "${base}/api/v2/token" 2>/dev/null || true)
        tok=$(echo "$resp" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 || true)
    fi
    echo "$tok"
}

init_sftpgo_auth() {
    local port="${SFTPGO_WEB_PORT:-8080}" pass="${ADMIN_PASSWORD}"
    local user="${ADMIN_USER:-admin}" base="http://127.0.0.1:${port}"
    log_info "Attente du démarrage de SFTPGo sur le port $port..."
    if ! wait_for_http "${base}/web/admin/login" 25; then
        log_warn "SFTPGo n'a pas répondu à temps." && return 0
    fi
    local tok && tok=$(get_sftpgo_token "$base" "$user" "$pass")
    if [[ -z "$tok" ]]; then
        log_warn "Jeton SFTPGo indisponible pour '$user'." && return 0
    fi
    if [[ "$user" != "admin" ]]; then
        local adm_code && adm_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $tok" "${base}/api/v2/admins/${user}")
        if [[ "$adm_code" == "404" ]]; then
            curl -s -X POST -H "Authorization: Bearer $tok" -H "Content-Type: application/json" \
                -d "{\"username\":\"${user}\",\"password\":\"${pass}\",\"status\":1,\"permissions\":[\"*\"]}" "${base}/api/v2/admins" >/dev/null 2>&1 || true
        fi
    fi
    log_info "Synchronisation compte SFTPGo ('$user')..."
    local code && code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $tok" "${base}/api/v2/users/${user}")
    local u_payload="{\"username\":\"${user}\",\"password\":\"${pass}\",\"status\":1,\"home_dir\":\"/srv/sftpgo/data/${user}\",\"permissions\":{\"/\" :[\"*\"]}}"
    if [[ "$code" == "404" ]]; then
        curl -s -X POST -H "Authorization: Bearer $tok" -H "Content-Type: application/json" -d "$u_payload" "${base}/api/v2/users" >/dev/null
        log_success "Compte SFTPGo '$user' créé (WebClient et SFTP)."
    elif [[ "$code" == "200" ]]; then
        curl -s -X PUT -H "Authorization: Bearer $tok" -H "Content-Type: application/json" -d "$u_payload" "${base}/api/v2/users/${user}" >/dev/null
        log_success "Compte SFTPGo '$user' synchronisé."
    fi
}

main() {
    log_info "=== Étape 5 : Initialisation et synchronisation des identifiants ==="
    init_zoraxy_admin
    init_sftpgo_auth
    log_success "Étape 5 terminée avec succès."
}

main "$@"
