# Configurations Système et Services

Ce répertoire centralise les modèles et fichiers de configuration requis par la stack IVPS.

## Contenu

- **`cockpit/cockpit.conf.example`** : modèle de configuration Cockpit (origines autorisées par Zoraxy, en-têtes `X-Forwarded-*`, terminaison TLS au proxy).
- **`sysctl/99-ivps-ports.conf`** : autorise Podman rootless à écouter sur les ports 80/443 (`net.ipv4.ip_unprivileged_port_start=80`).
- **`sysctl/99-ivps-wireguard.conf`** : active le forwarding IPv4/IPv6 et `src_valid_mark` requis par wg-easy en `Network=host`.
- **`modules-load/ivps-wireguard.conf`** : charge `wireguard` et `nft_masq` au démarrage.

## Déploiement

Ces configurations sont appliquées automatiquement par :

- [`scripts/02_install_components.sh`](../scripts/02_install_components.sh) pour les ports rootless ;
- [`scripts/02_install_wireguard.sh`](../scripts/02_install_wireguard.sh) pour les modules noyau et les sysctls WireGuard ;
- [`scripts/03_configure.sh`](../scripts/03_configure.sh) pour Cockpit ;
- [`scripts/03_firewall.sh`](../scripts/03_firewall.sh) pour le pare-feu.

Les fichiers sont installés dans `/etc/sysctl.d/`, `/etc/modules-load.d/` et `/etc/cockpit/`. Ils ne sont jamais modifiés directement dans ce dépôt.
