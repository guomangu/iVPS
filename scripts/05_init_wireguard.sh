#!/usr/bin/env bash
# ==============================================================================
# 05_init_wireguard.sh - Vérification wg-easy et correction de l'interface WAN
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"
load_env "${ROOT_DIR}/.env"
# shellcheck source=scripts/wireguard.sh
source "${SCRIPT_DIR}/wireguard.sh"

wait_for_wg_ui() {
    local url="http://127.0.0.1:${WG_UI_PORT:-9999}/" code
    for ((i = 1; i <= 25; i++)); do
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$url" 2>/dev/null || true)
        [[ "$code" =~ ^(2|3|401) ]] && return 0
        sleep 1
    done
    return 1
}

detect_wan_device() {
    local device="${WG_WAN_DEVICE:-auto}"
    if [[ "$device" == "auto" ]]; then
        device=$(ip -4 route show default 2>/dev/null | \
            awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i + 1); exit}}')
    fi
    echo "$device"
}

read_db_device() {
    run_sudo python3 - "$WG_DB_FILE" <<'PY' 2>/dev/null || true
import sqlite3, sys
try:
    with sqlite3.connect(sys.argv[1]) as db:
        row = db.execute("select device from interfaces_table where name='wg0'").fetchone()
        print(row[0] if row else "")
except Exception:
    print("")
PY
}

patch_db_device() {
    run_sudo systemctl stop "$WG_SERVICE"
    if ! run_sudo python3 - "$WG_DB_FILE" "$1" <<'PY'
import sqlite3, sys
with sqlite3.connect(sys.argv[1]) as db:
    db.execute("update interfaces_table set device=? where name='wg0'", (sys.argv[2],))
PY
    then
        log_error "Échec de la mise à jour NAT de wg-easy."
    fi
    run_sudo systemctl start "$WG_SERVICE"
}
fix_wan_interface() {
    local device current
    device=$(detect_wan_device)
    if [[ -z "$device" ]]; then
        log_warn "Interface WAN introuvable : NAT WireGuard non vérifié."
        return 0
    fi
    for ((i = 1; i <= 20; i++)); do
        run_sudo test -f "$WG_DB_FILE" 2>/dev/null && break
        sleep 1
    done
    if ! run_sudo test -f "$WG_DB_FILE" 2>/dev/null; then
        log_warn "Base wg-easy absente : interface WAN non vérifiée."
        return 0
    fi
    current=$(read_db_device | tr -d '[:space:]')
    if [[ -n "$current" && "$current" != "$device" ]]; then
        log_info "Correction NAT WireGuard : $current -> $device."
        patch_db_device "$device"
        wait_for_wg_ui || true
    else
        log_success "Interface WAN WireGuard : ${current:-non initialisée}."
    fi
}
main() {
    if [[ "${WG_ENABLED:-true}" != "true" ]]; then
        log_info "WireGuard désactivé (WG_ENABLED=false), étape ignorée."
        return 0
    fi
    log_info "=== Étape 5b : Vérification WireGuard ==="
    if ! systemctl is-active --quiet "$WG_SERVICE"; then
        log_warn "Service $WG_SERVICE inactif : journalctl -u $WG_SERVICE -n 30"
        return 0
    fi
    if wait_for_wg_ui; then
        log_success "UI wg-easy accessible sur 127.0.0.1:${WG_UI_PORT:-9999}."
    else
        log_warn "UI wg-easy non joignable (démarrage en cours ?)."
    fi
    fix_wan_interface
    log_success "Étape 5b terminée."
}

main "$@"
