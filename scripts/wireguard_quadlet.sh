#!/usr/bin/env bash
# ==============================================================================
# wireguard_quadlet.sh - Environnement wg-easy et rendu de l'unité Quadlet
# ==============================================================================
# Prérequis : common.sh et wireguard.sh sourcés.

wg_write_env() {
    local tmp init_enabled="${WG_INIT_ENABLED:-true}" host="${WG_INIT_HOST:-}"
    [[ -n "$host" ]] || init_enabled="false"
    tmp=$(mktemp)
    cat >"$tmp" <<EOF
TZ=${TZ:-UTC}
PORT=${WG_UI_PORT:-9999}
HOST=${WG_UI_BIND:-127.0.0.1}
INSECURE=${WG_INSECURE:-false}
INIT_ENABLED=${init_enabled}
INIT_USERNAME=${WG_INIT_USERNAME}
INIT_PASSWORD=${WG_INIT_PASSWORD}
INIT_HOST=${host}
INIT_PORT=${WG_LISTEN_PORT:-51820}
INIT_DNS=${WG_DNS:-1.1.1.1}
INIT_IPV4_CIDR=${WG_TUNNEL_CIDR:-10.8.0.0/24}
INIT_ALLOWED_IPS=${WG_ALLOWED_IPS:-0.0.0.0/0,::/0}
DISABLE_IPV6=${WG_DISABLE_IPV6:-false}
EOF
    run_sudo install -m 600 "$tmp" "$WG_ENV_FILE"
    rm -f "$tmp"
}

wg_install_quadlet() {
    local tmp
    run_sudo mkdir -p "$(dirname "$WG_QUADLET_DST")"
    tmp=$(mktemp)
    sed -e "s|@WG_IMAGE@|${WG_IMAGE:-ghcr.io/wg-easy/wg-easy:15}|g" \
        -e "s|@WG_ENV_FILE@|${WG_ENV_FILE}|g" \
        -e "s|@WG_DATA_DIR@|${WG_DATA_DIR}|g" "$WG_QUADLET_SRC" >"$tmp"
    run_sudo install -m 644 "$tmp" "$WG_QUADLET_DST"
    rm -f "$tmp"
    run_sudo systemctl daemon-reload
}
