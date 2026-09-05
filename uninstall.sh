#!/usr/bin/env bash
# ==============================================================================
# uninstall.sh - Script principal de désinstallation de la stack IVPS
# ==============================================================================
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${PROJECT_DIR}/scripts/common.sh"

show_help() {
    cat <<EOF
Usage: ./uninstall.sh [OPTIONS]

Options:
  -y, --yes, --force    Désinstallation sans invite de confirmation
  --purge               Supprime également les données persistantes (./data)
  -h, --help            Affiche cette aide
EOF
    exit 0
}

confirm_action() {
    local force=false purge=false
    for arg in "$@"; do
        case "$arg" in
            -y|--yes|--force) force=true ;;
            --purge)          purge=true ;;
            -h|--help)        show_help ;;
        esac
    done

    if [[ "$force" != "true" ]]; then
        local msg="Êtes-vous sûr de vouloir désinstaller la stack IVPS ? [o/O/y/Y/N] "
        if [[ "$purge" == "true" ]]; then
            msg="ATTENTION : L'option --purge supprimera également le dossier de données (./data). Continuer ? [o/O/y/Y/N] "
        fi
        read -r -p "$msg" response
        case "$response" in
            [yY][eE][sS]|[yY]|[oO][uU][iI]|[oO]) return 0 ;;
            *)
                log_info "Désinstallation annulée."
                exit 0
                ;;
        esac
    fi
}

main() {
    for arg in "$@"; do
        [[ "$arg" == "-h" || "$arg" == "--help" ]] && show_help
    done
    confirm_action "$@"
    bash "${PROJECT_DIR}/scripts/05_uninstall.sh" "$@"
}

main "$@"
