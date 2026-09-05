#!/usr/bin/env bash
# ==============================================================================
# uninstall.sh - Script principal de désinstallation de la stack IVPS
# ==============================================================================
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${PROJECT_DIR}/scripts/common.sh"

confirm_action() {
    if [[ "${1:-}" != "-y" && "${1:-}" != "--force" ]]; then
        read -r -p "Êtes-vous sûr de vouloir désinstaller la stack IVPS ? [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY])
                return 0
                ;;
            *)
                log_info "Désinstallation annulée."
                exit 0
                ;;
        esac
    fi
}

main() {
    confirm_action "${1:-}"
    bash "${PROJECT_DIR}/scripts/05_uninstall.sh" "$@"
}

main "$@"
