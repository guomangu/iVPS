#!/usr/bin/env bash
# ==============================================================================
# 02_install_components.sh - Ports dynamiques, mdp centralisé, stockage et Podman
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "$ENV_FILE"

stop_stack_if_running() {
    systemctl --user is-active --quiet ivps-stack.service 2>/dev/null && \
        systemctl --user stop ivps-stack.service 2>/dev/null || true
    command -v podman >/dev/null 2>&1 && podman stop ivps-zoraxy ivps-sftpgo 2>/dev/null || true
}

resolve_security_and_ports() {
    stop_stack_if_running
    if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
        update_env_var "ADMIN_PASSWORD" "$(generate_password 20)" "$ENV_FILE"
        log_success "Mot de passe administrateur généré automatiquement."
    fi
    [[ "$(get_env_or_default "COCKPIT_PORT" "9090")" -ne 9090 ]] && update_env_var "COCKPIT_PORT" "9090" "$ENV_FILE"

    local ports_keys=("ZORAXY_ADMIN_PORT:8000" "SFTPGO_WEB_PORT:8080" "SFTPGO_SFTP_PORT:2022")
    for item in "${ports_keys[@]}"; do
        local key="${item%%:*}" def="${item##*:}" cur
        cur=$(get_env_or_default "$key" "$def")
        if ! is_port_in_use "$def"; then
            [[ "$cur" -ne "$def" ]] && update_env_var "$key" "$def" "$ENV_FILE"
        elif is_port_in_use "$cur"; then
            local free_p
            free_p=$(find_free_port "$cur")
            log_warn "Port $cur ($key) utilisé ! Attribution dynamique du port $free_p."
            update_env_var "$key" "$free_p" "$ENV_FILE"
        fi
    done
}

setup_storage_and_selinux() {
    local base="${DATA_DIR:-${ROOT_DIR}/data}"
    log_info "Création des répertoires de données dans $base..."
    mkdir -p "${base}/zoraxy/config" "${base}/zoraxy/plugin" "${base}/sftpgo/data" "${base}/sftpgo/srv"
    chmod 755 "$base" 2>/dev/null || true
    chmod -R 755 "${base}/zoraxy" 2>/dev/null || true

    if command -v getenforce >/dev/null 2>&1; then
        log_info "Application du contexte SELinux (container_file_t)..."
        run_sudo chcon -R -t container_file_t "$base" 2>/dev/null || true
    fi
    if command -v podman >/dev/null 2>&1; then
        log_info "Ajustement des permissions Podman rootless pour SFTPGo..."
        podman unshare chown -R 1000:1000 "${base}/sftpgo" 2>/dev/null || true
        podman unshare chmod -R 775 "${base}/sftpgo" 2>/dev/null || true
    fi
}

setup_unprivileged_ports_and_network() {
    if [[ "${ENABLE_UNPRIVILEGED_PORTS:-true}" == "true" ]]; then
        local sysctl_file="/etc/sysctl.d/99-ivps-ports.conf"
        log_info "Autorisation des ports 80/443 pour Podman rootless..."
        echo "net.ipv4.ip_unprivileged_port_start=80" | run_sudo tee "$sysctl_file" >/dev/null
        run_sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80 >/dev/null 2>&1 || true
        run_sudo sysctl --system >/dev/null 2>&1 || true
    fi
    local net="${PODMAN_NETWORK:-ivps-net}"
    if ! podman network exists "$net" 2>/dev/null; then
        log_info "Création du réseau Podman '$net'..."
        podman network create "$net"
    fi
}

main() {
    log_info "=== Étape 2 : Composants centraux, sécurité et ports dynamiques ==="
    resolve_security_and_ports
    setup_storage_and_selinux
    setup_unprivileged_ports_and_network
    log_info "Téléchargement des images Podman..."
    podman pull "${ZORAXY_IMAGE:-zoraxydocker/zoraxy:latest}"
    podman pull "${SFTPGO_IMAGE:-drakkan/sftpgo:latest}"
    log_success "Étape 2 terminée avec succès."
}

main "$@"
