# Configurations Système et Services

Ce répertoire centralise les modèles et fichiers de configuration requis par la stack IVPS.

## Contenu

- **`cockpit/cockpit.conf`** : Modèle de configuration pour le service web Cockpit.
  - Définit les origines autorisées (Reverse Proxy Zoraxy).
  - Active la reconnaissance des en-têtes `X-Forwarded-Proto` et `X-Forwarded-For`.
  - Autorise la terminaison TLS sur le Reverse Proxy.
- **`sysctl/99-ivps-ports.conf`** : Configuration noyau pour autoriser Podman rootless à écouter sur les ports privilégiés 80 et 443 (`net.ipv4.ip_unprivileged_port_start=80`).

## Déploiement

Ces configurations sont automatiquement appliquées lors de l'exécution de :
- [`scripts/02_install_components.sh`](file:///home/gamo/Documents/ivps/scripts/02_install_components.sh)
- [`scripts/03_configure.sh`](file:///home/gamo/Documents/ivps/scripts/03_configure.sh)
