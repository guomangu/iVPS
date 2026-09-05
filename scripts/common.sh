#!/usr/bin/env bash
# ==============================================================================
# common.sh - Fonctions utilitaires partagées pour la stack IVPS
# ==============================================================================
set -euo pipefail

# Couleurs ANSI pour l'affichage terminal
readonly C_RESET='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'

# Fonctions de journalisation formatées
log_info()    { echo -e "${C_BLUE}[INFO]${C_RESET} $*"; }
log_success() { echo -e "${C_GREEN}[OK]${C_RESET} $*"; }
log_warn()    { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
log_error()   { echo -e "${C_RED}[ERREUR]${C_RESET} $*" >&2; }

# Charge les variables depuis le fichier .env
load_env() {
    local env_file="${1:-.env}"
    if [[ -f "$env_file" ]]; then
        # Exporte les variables en ignorant les commentaires et lignes vides
        set -a
        # shellcheck disable=SC1090
        source <(grep -E -v '^#|^$' "$env_file")
        set +a
        log_info "Environnement chargé depuis $env_file"
    else
        log_warn "Fichier $env_file non trouvé, utilisation des valeurs par défaut"
    fi
}

# Détecte le gestionnaire de paquets Linux du système hôte
detect_pkg_mgr() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    else
        log_error "Gestionnaire de paquets non supporté."
        exit 1
    fi
}

# Exécute une commande avec sudo si l'utilisateur n'est pas root
run_sudo() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}
