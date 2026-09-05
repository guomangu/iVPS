#!/usr/bin/env bash
# ==============================================================================
# 04_systemd_linger.sh - Activation du lingering et service systemd utilisateur
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "${ROOT_DIR}/.env"

enable_user_linger() {
    local target_user="${USER:-$(whoami)}"
    log_info "Activation du lingering systemd pour l'utilisateur : $target_user"
    run_sudo loginctl enable-linger "$target_user"
    log_success "Lingering activé pour $target_user."
}

install_user_service() {
    local user_systemd_dir="${HOME}/.config/systemd/user"
    local service_file="${user_systemd_dir}/ivps-stack.service"
    local podman_bin
    podman_bin="$(command -v podman)"

    mkdir -p "$user_systemd_dir"
    log_info "Génération de l'unité systemd utilisateur : $service_file"

    cat <<EOF > "$service_file"
[Unit]
Description=IVPS Stack (Zoraxy & SFTPGo via Podman Compose)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${ROOT_DIR}
ExecStart=${podman_bin} compose -f ${ROOT_DIR}/compose.yaml up -d
ExecStop=${podman_bin} compose -f ${ROOT_DIR}/compose.yaml down
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
EOF
    log_success "Unité $service_file créée."
}

enable_and_start_service() {
    log_info "Rechargement du démon systemd utilisateur..."
    systemctl --user daemon-reload
    log_info "Activation et démarrage du service ivps-stack..."
    systemctl --user enable --now ivps-stack.service
    log_success "Service ivps-stack activé et démarré."
}

main() {
    log_info "=== Étape 4 : Configuration du Lingering et de Systemd User ==="
    enable_user_linger
    install_user_service
    enable_and_start_service
    log_success "Étape 4 terminée avec succès."
}

main "$@"
