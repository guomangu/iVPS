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
    for ((i = 1; i <= ${2:-25}; i++)); do
        curl -s -L -f -o /dev/null "$1" 2>/dev/null && return 0
        sleep 1
    done && return 1
}

register_zoraxy() {
    local base="$1" user="$2" pass="$3" jar="$4" html csrf
    html=$(curl -s -c "$jar" "${base}/login.html")
    csrf=$(echo "$html" | grep -o 'name="zoraxy\.csrf\.Token" content="[^"]*"' | sed -E 's/.*content="([^"]+)".*/\1/' || true)
    [[ -n "$csrf" ]] && curl -s -b "$jar" -H "X-CSRF-Token: $csrf" -d "username=${user}&password=${pass}" "${base}/api/auth/register" >/dev/null
}

init_zoraxy_admin() {
    local port="${ZORAXY_ADMIN_PORT:-8000}" pass="${ADMIN_PASSWORD}" user="${ADMIN_USER:-admin}"
    local base="http://127.0.0.1:${port}" jar html csrf count l_res=""
    jar=$(mktemp)
    log_info "Attente du démarrage de Zoraxy sur le port $port..."
    wait_for_http "${base}/login.html" 25 || { log_warn "Zoraxy n'a pas répondu."; rm -f "$jar"; return 0; }
    html=$(curl -s -c "$jar" "${base}/login.html")
    csrf=$(echo "$html" | grep -o 'name="zoraxy\.csrf\.Token" content="[^"]*"' | sed -E 's/.*content="([^"]+)".*/\1/' || true)
    count=$(curl -s -b "$jar" "${base}/api/auth/userCount" 2>/dev/null || echo "1")
    [[ "$count" != "0" && -n "$csrf" ]] && l_res=$(curl -s -b "$jar" -c "$jar" -H "X-CSRF-Token: $csrf" -d "username=${user}&password=${pass}" "${base}/api/auth/login" 2>/dev/null || true)

    if [[ "$count" == "0" ]]; then
        register_zoraxy "$base" "$user" "$pass" "$jar"
        log_success "Compte administrateur Zoraxy '$user' initialisé."
    elif [[ "$l_res" == "\"OK\"" ]]; then
        log_success "Compte administrateur Zoraxy '$user' déjà synchronisé."
    else
        log_warn "Identifiants Zoraxy non synchronisés avec le .env. Réinitialisation..."
        podman stop ivps-zoraxy >/dev/null 2>&1 || true
        rm -f "${ROOT_DIR}/data/zoraxy/config/sys.db"
        podman start ivps-zoraxy >/dev/null 2>&1 || true
        wait_for_http "${base}/login.html" 25
        register_zoraxy "$base" "$user" "$pass" "$jar"
        log_success "Compte administrateur Zoraxy '$user' réinitialisé et synchronisé."
    fi
    rm -f "$jar"
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
    local port="${SFTPGO_WEB_PORT:-8080}" pass="${ADMIN_PASSWORD}" user="${ADMIN_USER:-admin}" base="http://127.0.0.1:${port}"
    log_info "Attente du démarrage de SFTPGo sur le port $port..."
    wait_for_http "${base}/web/admin/login" 25 || { log_warn "SFTPGo n'a pas répondu."; return 0; }
    local tok && tok=$(get_sftpgo_token "$base" "$user" "$pass")
    [[ -z "$tok" ]] && { log_warn "Jeton SFTPGo indisponible pour '$user'."; return 0; }

    if [[ "$user" != "admin" ]]; then
        local adm_code && adm_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $tok" "${base}/api/v2/admins/${user}")
        [[ "$adm_code" == "404" ]] && curl -s -X POST -H "Authorization: Bearer $tok" -H "Content-Type: application/json" \
            -d "{\"username\":\"${user}\",\"password\":\"${pass}\",\"status\":1,\"permissions\":[\"*\"]}" "${base}/api/v2/admins" >/dev/null 2>&1 || true
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
