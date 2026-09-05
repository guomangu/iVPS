# Scripts d'Automatisation IVPS

Ce répertoire regroupe les scripts modulaires et idempotents responsables du cycle de vie de la stack IVPS.

## Structure et Responsabilités

| Script | Description |
|---|---|
| [`common.sh`](file:///home/gamo/Documents/ivps/scripts/common.sh) | Fonctions transverses : affichage coloré, chargement du `.env`, détection de l'OS. |
| [`01_install_deps.sh`](file:///home/gamo/Documents/ivps/scripts/01_install_deps.sh) | Détecte le gestionnaire (`apt`, `dnf`, `pacman`) et installe Podman, Cockpit et utilitaires. |
| [`02_install_components.sh`](file:///home/gamo/Documents/ivps/scripts/02_install_components.sh) | Crée l'arborescence des volumes, configure sysctl (ports 80/443 rootless) et le réseau Podman. |
| [`03_configure.sh`](file:///home/gamo/Documents/ivps/scripts/03_configure.sh) | Configure Cockpit (`/etc/cockpit/cockpit.conf`), le pare-feu et déclenche le provisionnement Zoraxy. |
| [`03_zoraxy_rules.sh`](file:///home/gamo/Documents/ivps/scripts/03_zoraxy_rules.sh) | Pré-configure les règles HTTP de routage Zoraxy (Cockpit, SFTPGo, Proxy) et la page d'accueil. |
| [`04_systemd_linger.sh`](file:///home/gamo/Documents/ivps/scripts/04_systemd_linger.sh) | Active `loginctl enable-linger` et déploie l'unité `systemd --user` `ivps-stack.service`. |
| [`05_uninstall.sh`](file:///home/gamo/Documents/ivps/scripts/05_uninstall.sh) | Arrête les conteneurs, supprime le service systemd utilisateur et nettoie les configurations. |

## Utilisation Autonome

Chaque script peut être exécuté individuellement avec des privilèges normaux (les étapes nécessitant `sudo` le sollicitent automatiquement) :

```bash
bash scripts/01_install_deps.sh
bash scripts/02_install_components.sh
bash scripts/03_configure.sh
bash scripts/04_systemd_linger.sh
```
