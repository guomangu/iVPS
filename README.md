# 🚀 IVPS - Stack d'Administration VPS Hybride, Sécurisée & VPN WireGuard

[![Podman](https://img.shields.io/badge/Podman-Rootless%20%2B%20Rootful-892CA0?logo=podman&logoColor=white)](https://podman.io/)
[![Zoraxy](https://img.shields.io/badge/Zoraxy-Reverse--Proxy%20%26%20WAF-007ACC)](https://zoraxy.arozos.com/)
[![Cockpit](https://img.shields.io/badge/Cockpit-Console%20OS-005050)](https://cockpit-project.org/)
[![pgAdmin](https://img.shields.io/badge/pgAdmin-Web%20%26%20SFTP-4CAF50)](https://pgadmin.com/)
[![WireGuard](https://img.shields.io/badge/WireGuard-wg--easy-88171A?logo=wireguard&logoColor=white)](https://github.com/wg-easy/wg-easy)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Stack d'administration moderne, légère et automatisée pour VPS (Fedora, RHEL, Debian, Ubuntu). Elle associe **Cockpit** (administration système native), **Zoraxy** (Reverse Proxy & WAF), **pgAdmin** (administration PostgreSQL) et **wg-easy** (VPN WireGuard + interface web). Zoraxy et pgAdmin restent en **Podman rootless** ; seul wg-easy est **rootful**, car le tunnel `wg0` doit vivre dans le namespace réseau de l'hôte pour être joignable par le reverse proxy.

---

## 🎯 Composants de la Stack

1. **Zoraxy** *(Podman rootless, `--network host`)* : Reverse Proxy, WAF applicatif, certificats SSL/TLS Let's Encrypt, GeoIP blocking et redirection HTTPS automatique.
2. **Cockpit** *(Service natif Host OS)* : Tour de contrôle système activée par socket systemd (consommation mémoire nulle au repos), surveillance des ressources, gestion des paquets et du stockage.
3. **pgAdmin** *(Podman rootless, `--network host`)* : Interface web d'administration PostgreSQL.
4. **WireGuard / wg-easy** *(Podman rootful, `--network host`, Quadlet)* : VPN WireGuard et interface d'administration web. Le tunnel `10.8.0.0/24` est créé directement sur l'hôte, ce qui permet à Zoraxy d'exposer des services situés **à l'intérieur** du VPN.

---

## 🏗️ Architecture et Flux Réseau

```text
[ Internet : 80 / 443 ] ──► Zoraxy Reverse Proxy (Podman rootless, --network host)
                               ├── admin.domaine.com  ──► Cockpit Console OS (:9090)
                               ├── proxy.domaine.com  ──► Zoraxy Admin Web (:8000)
                               ├── db.domaine.com     ──► pgAdmin Web (:5050)
                               └── vpn.domaine.com    ──► wg-easy UI (127.0.0.1:9999)

[ Internet : UDP 51820 ] ──► ivps-wireguard (Podman rootful, --network host)
                               └── wg0 : 10.8.0.0/24 visible sur l'hôte
```

> [!IMPORTANT]
> **Pourquoi un conteneur rootful ?** Un conteneur rootless ne peut pas créer `wg0` dans le namespace réseau de l'hôte. Sans cela, Zoraxy ne pourrait pas router `okay.domaine.com` vers un client du tunnel (`10.8.0.2:8096`, par exemple). C'est la seule exception rootless/rootful de la stack.

---

## 🛡️ Fonctionnalités Clés & Robustesse

- **Routage Automatisé (Zero-Conf)** : Les règles de proxy JSON (`proxy.*`, `admin.*`, `db.*`, `vpn.*`) sont générées dès l'installation — aucun paramétrage manuel préalable.
- **Accès Direct par Sous-Domaines** : Aucun portail non authentifié sur le domaine racine. Chaque service dispose de son sous-domaine dédié.
- **Identifiants Centraux** :
  - **Cockpit** : utilisateur système `ADMIN_USER` rattaché à `wheel`/`sudo`, mot de passe synchronisé.
  - **Zoraxy** : vérification active de session, avec auto-guérison si les identifiants divergent du `.env`.
  - **pgAdmin** : identifiants générés à partir de `ADMIN_USER` et `ADMIN_PASSWORD`.
  - **wg-easy** : au **premier démarrage d'une base vide**, l'admin reprend `ADMIN_USER` et `ADMIN_PASSWORD` (ou `WG_INIT_*`). Une base migrée depuis `reversevpn` conserve ses identifiants existants.
- **WireGuard amélioré** :
  - UI liée à **`127.0.0.1`** par défaut : elle n'est exposée que via Zoraxy, jamais directement sur Internet.
  - Détection automatique de l'interface WAN (`ens3`, `eth0`, …) et correction du NAT wg-easy sans intervention manuelle.
  - Module noyau et sysctls appliqués à l'hôte par l'installateur (`ip_forward`, `src_valid_mark`, forwarding IPv6).
  - Migration automatique des clés, clients et de la base SQLite de l'ancien projet `reversevpn`.
- **Support Podman Rootless & SELinux** : volumes `:Z,U`, permissions gérées avec `podman unshare` pour pgAdmin.
- **Allocation Dynamique & Idempotente des Ports** : les ré-exécutions évitent les collisions et rétablissent les ports standards.
- **Persistance Systemd (Linger)** : la stack rootless `ivps-stack.service` démarre au boot ; le service rootful `ivps-wireguard.service` est généré par Quadlet.
- **Pare-feu Automatique** : Firewalld (Fedora/RHEL) et UFW (Debian/Ubuntu), avec ouverture de `51820/udp` et du port UI uniquement si celui-ci n'écoute pas sur loopback.
- **Conformité & Modularité** : scripts courts et spécialisés, documentés dans [`scripts/README.md`](scripts/README.md) et [`bonne_pratique.md`](bonne_pratique.md).

---

## ⚙️ Configuration Rapide (`.env`)

Toutes les variables sont personnalisables dans le fichier `.env` à la racine du projet :

```ini
DOMAIN_NAME=votre-domaine.com
ZORAXY_SUBDOMAIN=proxy
COCKPIT_SUBDOMAIN=admin
PGADMIN_SUBDOMAIN=db
WG_SUBDOMAIN=vpn

# Utilisateur unifié (ex: votre utilisateur natif du VPS ou 'admin')
ADMIN_USER=admin
ADMIN_PASSWORD=             # Laisser vide pour génération aléatoire sécurisée

ZORAXY_ADMIN_PORT=8000
PGADMIN_PORT=5050
COCKPIT_PORT=9090

# WireGuard : UI privée (loopback) + tunnel sur UDP 51820
WG_ENABLED=true
WG_UI_PORT=9999
WG_UI_BIND=127.0.0.1
WG_INSECURE=false
WG_LISTEN_PORT=51820
WG_TUNNEL_CIDR=10.8.0.0/24
WG_WAN_DEVICE=auto
```

> [!NOTE]
> Le fichier `.env`, le dossier `data/` et l'environnement généré `data/wireguard/wg-easy.env` sont protégés par [`.gitignore`](.gitignore) et ne sont jamais poussés sur Git.

---

## ⚡ Déploiement en Une Commande

```bash
git clone https://github.com/votre-user/ivps.git
cd ivps
chmod +x install.sh uninstall.sh
./install.sh
```

> [!IMPORTANT]
> Exécutez toujours le script avec `./install.sh` ou `bash install.sh` (et non `sh install.sh`) afin de bénéficier de l'interpréteur Bash complet et du mode strict (`set -euo pipefail`).

L'installateur détecte l'ancien projet `reversevpn` (variable `WG_LEGACY_DIR`), arrête son service, importe ses données dans `data/wireguard/`, puis installe `ivps-wireguard.service`. L'ancien dossier peut être supprimé **après validation** du bon fonctionnement.

---

## 🔑 Tableau Récapitulatif des Accès

| Interface | Service | Accès Web (Reverse Proxy) | Port Direct Hôte | Identifiants configurés |
|---|---|---|---|---|
| **Zoraxy Web Admin** | Reverse Proxy & WAF | `https://proxy.domaine.com` | `:8000` | `<ADMIN_USER>` / `<ADMIN_PASSWORD>` |
| **Cockpit Console OS** | Administration Système | `https://admin.domaine.com` | `:9090` | `<ADMIN_USER>` / `<ADMIN_PASSWORD>` |
| **pgAdmin Web** | Interface Web PostgreSQL | `https://db.domaine.com` | `:5050` | `<ADMIN_USER>@<DOMAIN>` / `<ADMIN_PASSWORD>` |
| **WireGuard wg-easy** | VPN & clients | `https://vpn.domaine.com` | `127.0.0.1:9999` (privé) | `<ADMIN_USER>` / `<ADMIN_PASSWORD>`* |
| **Tunnel WireGuard** | Accès VPN | *Non applicable* | `UDP 51820` | Clés par client |

\* Identifiants appliqués à la **première initialisation**. Une base migrée depuis `reversevpn` conserve son compte existant.

---

## 🧩 Migrer l'ancien projet `reversevpn`

La migration est automatique à la première exécution de `./install.sh` :

1. arrêt et retrait de l'ancienne unité Quadlet `wg-easy.service` ;
2. copie de `reversevpn/data/` vers `data/wireguard/` (clés, clients, base SQLite) ;
3. reprise des valeurs `INIT_*` de `reversevpn/.env` si les variables `WG_INIT_*` sont vides ;
4. démarrage de `ivps-wireguard.service` ;
5. correction automatique de l'interface WAN dans la base wg-easy.

Vérifications :

```bash
systemctl status ivps-wireguard.service
sudo podman exec ivps-wireguard wg show
ip a show wg0
ip route get 10.8.0.2
```

Une fois le VPN et `https://vpn.domaine.com` validés, `~/reversevpn` peut être archivé ou supprimé.

---

## 🛠️ Commandes Usuelles

```bash
# Statut de la stack rootless
systemctl --user status ivps-stack.service

# Statut du service WireGuard rootful (Quadlet)
systemctl status ivps-wireguard.service

# Journaux
journalctl --user -u ivps-stack.service -f
journalctl -u ivps-wireguard.service -f

# Pairs WireGuard connectés
sudo podman exec ivps-wireguard wg show

# Mettre à jour la configuration, l'utilisateur ou le mot de passe
nano .env
./install.sh

# Désinstallation complète et nettoyage propre
./uninstall.sh            # conserve data/
./uninstall.sh --purge    # supprime aussi data/
```

---

## 📚 Documentation

- [`Architecture de la Stack VPS.md`](Architecture%20de%20la%20Stack%20VPS.md) : flux réseau détaillé et rôle de chaque brique.
- [`scripts/README.md`](scripts/README.md) : responsabilité de chaque script.
- [`containers/README.md`](containers/README.md) : images, modes réseau et cycle de vie.
- [`containers/wireguard/README.md`](containers/wireguard/README.md) : spécificités wg-easy et dépannage.
- [`config/README.md`](config/README.md) : configurations système appliquées.
