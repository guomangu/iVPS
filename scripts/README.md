# Scripts d'Automatisation IVPS

Ce répertoire regroupe les scripts modulaires et idempotents responsables du cycle de vie de la stack IVPS, chacun respectant la règle des **100 lignes maximum** ([`bonne_pratique.md`](file:///home/gamo/Documents/ivps/bonne_pratique.md)).

## Structure et Responsabilités

| Script | Description |
|---|---|
| [`common.sh`](file:///home/gamo/Documents/ivps/scripts/common.sh) | Fonctions transverses : affichage coloré, chargement du `.env`, détection de l'OS, allocation idempotente des ports. |
| [`01_install_deps.sh`](file:///home/gamo/Documents/ivps/scripts/01_install_deps.sh) | Détecte le gestionnaire (`dnf`, `apt`, `pacman`) et installe Podman, Cockpit et dépendances si non présentes. |
| [`02_install_components.sh`](file:///home/gamo/Documents/ivps/scripts/02_install_components.sh) | Génère le mot de passe maître, prépare l'arborescence des volumes, configure sysctl (ports 80/443 rootless) et le réseau Podman. |
| [`03_configure.sh`](file:///home/gamo/Documents/ivps/scripts/03_configure.sh) | Configure Cockpit (`/etc/cockpit/cockpit.conf`), crée l'utilisateur système OS `admin` (`wheel`/`sudo`), configure le pare-feu et déclenche les règles Zoraxy. |
| [`03_zoraxy_rules.sh`](file:///home/gamo/Documents/ivps/scripts/03_zoraxy_rules.sh) | Pré-configure les règles HTTP de routage direct pour les sous-domaines (`proxy.*`, `admin.*`, `folder.*`) sans portail public non filtré sur la racine. |
| [`04_systemd_linger.sh`](file:///home/gamo/Documents/ivps/scripts/04_systemd_linger.sh) | Active `loginctl enable-linger` et déploie l'unité `systemd --user` `ivps-stack.service`. |
| [`05_init_auth.sh`](file:///home/gamo/Documents/ivps/scripts/05_init_auth.sh) | Initialise automatiquement le compte administrateur Zoraxy et synchronise le compte `admin` SFTPGo (WebAdmin, WebClient et SFTP). |
| [`05_uninstall.sh`](file:///home/gamo/Documents/ivps/scripts/05_uninstall.sh) | Arrête les conteneurs, supprime le service systemd utilisateur et nettoie les configurations résiduelles. |

## Utilisation

L'orchestration globale est pilotée par le script racine [`install.sh`](file:///home/gamo/Documents/ivps/install.sh) :

```bash
chmod +x install.sh
./install.sh
# ou : bash install.sh
```

Chaque script peut également être exécuté individuellement dans l'ordre séquentiel.
