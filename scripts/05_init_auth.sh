#!/usr/bin/env bash
# ==============================================================================
# 05_init_auth.sh - Initialisation et synchronisation des accès Zoraxy
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

check_pgadmin() {
    local port="${PGADMIN_PORT:-5050}"
    local base="http://127.0.0.1:${port}"
    log_info "Attente du démarrage de pgAdmin 4 sur le port $port..."
    wait_for_http "${base}/login" 30 || { log_warn "pgAdmin n'a pas répondu à temps."; return 0; }
    log_success "pgAdmin 4 est prêt et opérationnel (configuré via variables d'environnement)."
}

main() {
    log_info "=== Étape 5 : Initialisation et synchronisation des identifiants ==="
    init_zoraxy_admin
    check_pgadmin
    log_success "Étape 5 terminée avec succès."
}

main "$@"
