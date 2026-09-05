#!/usr/bin/env bash
# ==============================================================================
# 04_systemd_linger.sh - Lingering et service utilisateur avec rechargement
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "${ROOT_DIR}/.env"

enable_user_linger() {
    local target_user="${USER:-$(whoami)}"
    local admin_user="${ADMIN_USER:-$target_user}"
    log_info "Vérification du lingering systemd pour : $target_user"
    for u in "$target_user" "$admin_user"; do
        if id "$u" >/dev/null 2>&1; then
            if ! loginctl show-user "$u" -p Linger 2>/dev/null | grep -q "yes"; then
                run_sudo loginctl enable-linger "$u"
                log_success "Lingering activé pour $u."
            fi
        fi
    done
}

install_user_service() {
    local user_systemd_dir="${HOME}/.config/systemd/user"
    local service_file="${user_systemd_dir}/ivps-stack.service"
    local compose_exec
    if command -v podman-compose >/dev/null 2>&1; then
        compose_exec="$(command -v podman-compose)"
    else
        compose_exec="$(command -v podman) compose"
    fi

    mkdir -p "$user_systemd_dir"
    log_info "Mise à jour de l'unité systemd : $service_file"

    cat <<EOF > "$service_file"
[Unit]
Description=IVPS Stack (Zoraxy & SFTPGo via Podman Compose)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${ROOT_DIR}
ExecStart=${compose_exec} -f ${ROOT_DIR}/compose.yaml up -d
ExecStop=${compose_exec} -f ${ROOT_DIR}/compose.yaml down
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
EOF
}

enable_and_start_service() {
    log_info "Rechargement du démon systemd utilisateur..."
    systemctl --user daemon-reload
    log_info "Activation et redémarrage propre du service ivps-stack..."
    systemctl --user enable ivps-stack.service
    systemctl --user restart ivps-stack.service
    log_success "Stack Podman démarrée et synchronisée avec le .env."
}

main() {
    log_info "=== Étape 4 : Lingering et déploiement de l'unité systemd --user ==="
    enable_user_linger
    install_user_service
    enable_and_start_service
    log_success "Étape 4 terminée avec succès."
}

main "$@"
