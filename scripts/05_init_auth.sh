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
        if curl -s -L -f -o /dev/null "$url" 2>/dev/null; then return 0; fi
        sleep 1
    done
    return 1
}

init_zoraxy_admin() {
    local port="${ZORAXY_ADMIN_PORT:-8000}"
    local pass="${ADMIN_PASSWORD}"
    local base_url="http://127.0.0.1:${port}"
    local cookie_jar
    cookie_jar=$(mktemp)

    log_info "Attente du démarrage de Zoraxy sur le port $port..."
    if ! wait_for_http "${base_url}/login.html" 25; then
        log_warn "Zoraxy n'a pas répondu à temps pour l'initialisation des identifiants."
        rm -f "$cookie_jar"
        return 0
    fi

    local html csrf count
    html=$(curl -s -c "$cookie_jar" "${base_url}/login.html")
    csrf=$(echo "$html" | grep -o 'name="zoraxy\.csrf\.Token" content="[^"]*"' | sed -E 's/.*content="([^"]+)".*/\1/' || true)
    count=$(curl -s -b "$cookie_jar" "${base_url}/api/auth/userCount" 2>/dev/null || echo "1")

    if [[ "$count" == "0" && -n "$csrf" ]]; then
        log_info "Initialisation du compte administrateur Zoraxy ('admin')..."
        curl -s -b "$cookie_jar" \
            -H "X-CSRF-Token: $csrf" \
            -d "username=admin&password=${pass}" \
            "${base_url}/api/auth/register" >/dev/null
        log_success "Compte administrateur Zoraxy initialisé avec succès."
    else
        log_info "Compte administrateur Zoraxy déjà provisionné."
    fi
    rm -f "$cookie_jar"
}

init_sftpgo_auth() {
    local port="${SFTPGO_WEB_PORT:-8080}"
    local pass="${ADMIN_PASSWORD}"
    local base_url="http://127.0.0.1:${port}"

    log_info "Attente du démarrage de SFTPGo sur le port $port..."
    if ! wait_for_http "${base_url}/web/admin/login" 25; then
        log_warn "SFTPGo n'a pas répondu à temps pour la configuration utilisateur."
        return 0
    fi

    local token_resp token
    token_resp=$(curl -s -u "admin:${pass}" "${base_url}/api/v2/token" 2>/dev/null || true)
    token=$(echo "$token_resp" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 || true)

    if [[ -z "$token" ]]; then
        log_warn "Impossible d'obtenir le jeton admin SFTPGo. Vérifiez les identifiants."
        return 0
    fi

    log_info "Synchronisation du compte utilisateur SFTPGo ('admin')..."
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" "${base_url}/api/v2/users/admin")
    local user_payload="{\"username\":\"admin\",\"password\":\"${pass}\",\"status\":1,\"home_dir\":\"/srv/sftpgo/data/admin\",\"permissions\":{\"/\" :[\"*\"]}}"

    if [[ "$code" == "404" ]]; then
        curl -s -X POST -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
            -d "$user_payload" "${base_url}/api/v2/users" >/dev/null
        log_success "Compte utilisateur SFTPGo 'admin' créé avec succès (accès WebClient et SFTP)."
    elif [[ "$code" == "200" ]]; then
        curl -s -X PUT -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
            -d "$user_payload" "${base_url}/api/v2/users/admin" >/dev/null
        log_success "Compte utilisateur SFTPGo 'admin' mis à jour avec succès."
    fi
}

main() {
    log_info "=== Étape 5 : Initialisation et synchronisation des identifiants ==="
    init_zoraxy_admin
    init_sftpgo_auth
    log_success "Étape 5 terminée avec succès."
}

main "$@"
