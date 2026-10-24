# Scripts d'Automatisation IVPS

Ce répertoire regroupe les scripts modulaires et idempotents responsables du cycle de vie de la stack IVPS, chacun respectant la règle des **100 lignes maximum** ([`bonne_pratique.md`](../bonne_pratique.md)).

## Structure et Responsabilités

| Script | Description |
|---|---|
| [`common.sh`](common.sh) | Fonctions transverses : affichage coloré, chargement du `.env`, détection de l'OS, allocation idempotente des ports, génération de secrets. |
| [`wireguard.sh`](wireguard.sh) | Bibliothèque partagée wg-easy : chemins, migration `reversevpn`, détection IP publique et réglages noyau. |
| [`wireguard_quadlet.sh`](wireguard_quadlet.sh) | Bibliothèque de rendu : environnement `wg-easy.env` (droits 600) et unité Quadlet rootful. |
| [`01_install_deps.sh`](01_install_deps.sh) | Détecte le gestionnaire (`dnf`, `apt`, `pacman`) et installe Podman, Cockpit et les dépendances. |
| [`02_install_components.sh`](02_install_components.sh) | Initialise `ADMIN_USER`, génère `ADMIN_PASSWORD`, prépare les volumes, configure les ports rootless et le réseau Podman. |
| [`02_install_wireguard.sh`](02_install_wireguard.sh) | Désactive l'ancien service `reversevpn`, migre ses données, applique modules/sysctls, génère l'environnement wg-easy et l'unité Quadlet rootful, puis démarre `ivps-wireguard.service`. |
| [`03_configure.sh`](03_configure.sh) | Configure Cockpit, synchronise l'utilisateur OS et déclenche le pare-feu puis les règles Zoraxy. |
| [`03_firewall.sh`](03_firewall.sh) | Applique Firewalld/UFW : web, admin et UDP WireGuard (UI TCP seulement si exposée hors loopback). |
| [`03_zoraxy_rules.sh`](03_zoraxy_rules.sh) | Pré-configure les règles HTTP des sous-domaines `proxy.*`, `admin.*`, `db.*` et `vpn.*`. |
| [`04_systemd_linger.sh`](04_systemd_linger.sh) | Active `loginctl enable-linger` et déploie `ivps-stack.service` (`systemd --user`). |
| [`05_init_auth.sh`](05_init_auth.sh) | Vérifie et synchronise les accès Zoraxy (auto-guérison de `sys.db`) et pgAdmin. |
| [`05_init_wireguard.sh`](05_init_wireguard.sh) | Vérifie l'UI wg-easy et corrige automatiquement l'interface WAN utilisée par le NAT (`WG_WAN_DEVICE`). |
| [`05_uninstall.sh`](05_uninstall.sh) | Arrête les conteneurs rootless et rootful, retire les unités systemd/Quadlet et nettoie les configurations. |

## Ordre d'Exécution

L'orchestration globale est pilotée par [`install.sh`](../install.sh) :

```bash
chmod +x install.sh
./install.sh
# ou : bash install.sh
```

Chaque script peut aussi être exécuté individuellement, dans l'ordre numérique indiqué ci-dessus.

## Variables Utiles

- `WG_ENABLED` : active/désactive l'installation WireGuard.
- `WG_LEGACY_DIR` : emplacement de l'ancien projet `reversevpn` à migrer (défaut : `../reversevpn`).
- `WG_UI_BIND` : `127.0.0.1` (privé, via Zoraxy) ou `0.0.0.0` (accès direct).
- `WG_WAN_DEVICE` : `auto` ou nom de l'interface sortante (`ens3`, `eth0`, …).
