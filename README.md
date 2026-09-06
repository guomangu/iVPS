# 🚀 IVPS - Stack d'Administration VPS Hybride & Sécurisée

[![Podman](https://img.shields.io/badge/Podman-Rootless-892CA0?logo=podman&logoColor=white)](https://podman.io/)
[![Zoraxy](https://img.shields.io/badge/Zoraxy-Reverse--Proxy%20%26%20WAF-007ACC)](https://zoraxy.arozos.com/)
[![Cockpit](https://img.shields.io/badge/Cockpit-Console%20OS-008080)](https://cockpit-project.org/)
[![SFTPGo](https://img.shields.io/badge/SFTPGo-Web%20%26%20SFTP-4CAF50)](https://sftpgo.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Stack d'administration moderne, légère et automatisée pour VPS (Fedora, RHEL, Debian, Ubuntu). Elle associe la puissance de **Cockpit** (administration système native) à l'isolation de conteneurs **Podman rootless en mode host (`--network host`)** pour **Zoraxy** (Reverse Proxy & WAF) et **SFTPGo** (Gestionnaire de fichiers Web et serveur SFTP).

---

## 🎯 Composants de la Stack

1. **Zoraxy** *(Conteneur Podman Rootless, mode `--network host`)* : Reverse Proxy, WAF applicatif, gestionnaire de certificats SSL/TLS Let's Encrypt, GeoIP blocking et redirection HTTPS automatique.
2. **Cockpit** *(Service Natif Host OS)* : Tour de contrôle système activée par socket Systemd (consommation mémoire nulle au repos), surveillance des ressources en direct, gestionnaire de paquets et de stockage.
3. **SFTPGo** *(Conteneur Podman Rootless, mode `--network host`)* : Gestionnaire de fichiers Web moderne et serveur SFTP haute performance sur port dédié.

---

## 🏗️ Architecture et Flux Réseau

```text
[ Internet : 80 / 443 ] ──► Zoraxy Reverse Proxy (Podman Rootless, --network host)
                               ├── admin.domaine.com  ──► Cockpit Console OS (:9090)
                               ├── proxy.domaine.com  ──► Zoraxy Admin Web (:8000)
                               └── folder.domaine.com ──► SFTPGo Web (:8080)
[ Internet : 2022 ]    ────────────────────────────────► SFTPGo Serveur SFTP
```

---

## 🛡️ Fonctionnalités Clés & Robustesse

- **Routage Automatisé (Zero-Conf)** : Les règles de proxy JSON pour Zoraxy (`proxy.*`, `admin.*`, `folder.*`) sont générées dès l'installation : **aucun paramétrage manuel préalable n'est nécessaire**.
- **Accès Direct par Sous-Domaines** : Aucun portail non authentifié sur le domaine racine. Chaque service dispose de son sous-domaine dédié (`proxy.*`, `admin.*`, `folder.*`) sollicitant les identifiants centraux dès la connexion.
- **Identifiants Centraux, Synchronisation Continue & Auto-Guérison** :
  - **Utilisateur Personnalisable (`ADMIN_USER`)** : Choix libre de l'administrateur dans `.env` pour le synchroniser directement avec un utilisateur système natif déjà existant sur le VPS (ou en créer un nouveau).
  - **Cockpit** : Utilisateur système OS (`ADMIN_USER`) rattaché aux privilèges d'administration (`wheel`/`sudo`) et mot de passe synchronisé.
  - **Zoraxy** : Vérification active de session (`/api/auth/login`). En cas de changement dans `.env` ou de divergence, Zoraxy est automatiquement réinitialisé (purge de `sys.db` tout en conservant intacts les fichiers de routage `conf/proxy/`) et réenregistré avec les nouveaux identifiants.
  - **SFTPGo** : Compte (`ADMIN_USER`) synchronisé à la fois comme WebAdmin (`/web/admin`), WebClient (`/web/client`) et utilisateur SFTP (`port 2022`).
- **Support Podman Rootless & SELinux** :
  - Mode Réseau Hôte (`--network host`) : Communication directe et ultra-rapide sans latence de pont ni translation d'adresse (NAT).
  - Volumes montés avec les drapeaux `:Z,U` pour adapter la propriété aux conteneurs non-privilégiés.
  - Permissions récursives gérées avec `podman unshare` pour aligner les sous-UIDs (ex: UID `1000:1000` interne de SFTPGo) sans erreur de permission sur l'hôte.
- **Allocation Dynamique & Idempotente des Ports** :
  - Arrêt temporaire propre lors des ré-exécutions pour éviter les collisions avec ses propres conteneurs.
  - Rétablissement automatique des ports standards (`8000`, `8080`, `2022`) dès qu'ils sont libres.
  - Port natif de Cockpit verrouillé sur son écoute réelle (**`9090`**).
- **Mot de Passe Maître Centralisé** : Défini via `ADMIN_PASSWORD` dans [`.env`](file:///home/gamo/Documents/ivps/.env) (ou généré automatiquement si vide) et appliqué uniformément à tous les services via `./install.sh`.
- **Persistance Systemd (Linger)** : Service `systemd --user` (`ivps-stack.service`) activé avec `loginctl enable-linger` pour démarrer dès le boot du VPS sans session interactive ouverte.
- **Pare-feu Automatique** : Configuration persistante pour **Firewalld** (Fedora/RHEL) et **UFW** (Debian/Ubuntu).
- **Conformité & Modularité** : Chaque script fait strictement moins de 100 lignes de code et respecte les préconisations architecturales de [`bonne_pratique.md`](file:///home/gamo/Documents/ivps/bonne_pratique.md).

---

## ⚙️ Configuration Rapide (`.env`)

Toutes les variables sont personnalisables dans le fichier `.env` à la racine du projet :

```ini
DOMAIN_NAME=votre-domaine.com
ZORAXY_SUBDOMAIN=proxy
COCKPIT_SUBDOMAIN=admin
SFTPGO_SUBDOMAIN=folder

# Utilisateur unifié (ex: votre utilisateur natif du VPS ou 'admin')
ADMIN_USER=admin
ADMIN_PASSWORD=             # Laisser vide pour génération aléatoire sécurisée

ZORAXY_ADMIN_PORT=8000
SFTPGO_WEB_PORT=8080
SFTPGO_SFTP_PORT=2022
COCKPIT_PORT=9090
```

> [!NOTE]
> Le fichier `.env` ainsi que le dossier de données persistantes `data/` sont protégés par le [`.gitignore`](file:///home/gamo/Documents/ivps/.gitignore) et ne sont jamais poussés sur Git.

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

---

## 🔑 Tableau Récapitulatif des Accès

| Interface | Service | Accès Web (Reverse Proxy) | Port Direct Hôte | Identifiants configurés |
|---|---|---|---|---|
| **Zoraxy Web Admin** | Reverse Proxy & WAF | `https://proxy.domaine.com` | `:8000` | `<ADMIN_USER>` / `<ADMIN_PASSWORD>` |
| **Cockpit Console OS** | Administration Système | `https://admin.domaine.com` | `:9090` | `<ADMIN_USER>` / `<ADMIN_PASSWORD>` |
| **SFTPGo Web** | Gestionnaire Fichiers Web | `https://folder.domaine.com` | `:8080` | `<ADMIN_USER>` / `<ADMIN_PASSWORD>` |
| **SFTP Fichiers** | Transfert SFTP | *Non proxifié* | `:2022` | `<ADMIN_USER>` / `<ADMIN_PASSWORD>` |

---

## 🛠️ Commandes Usuelles

```bash
# Vérifier le statut du service utilisateur
systemctl --user status ivps-stack.service

# Consulter les journaux en temps réel
journalctl --user -u ivps-stack.service -f

# Mettre à jour la configuration, l'utilisateur ou le mot de passe
nano .env
./install.sh

# Désinstallation complète et nettoyage propre
./uninstall.sh
```
