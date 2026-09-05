# IVPS Stack : Zoraxy + Cockpit + SFTPGo

Stack d'administration VPS moderne, entièrement conteneurisée, hautement sécurisée et prête pour la production (**Fedora**, **RHEL**, **Debian**, **Ubuntu**). 

Elle associe **Cockpit** (gestion OS native légère), **Podman rootless** avec **Zoraxy** (Reverse Proxy, WAF & SSL automatisé) et **SFTPGo** (Explorateur Web & SFTP).

[![Podman](https://img.shields.io/badge/Podman-Rootless-purple.svg)](https://podman.io)
[![Fedora](https://img.shields.io/badge/Fedora-Ready-blue.svg)](https://fedoraproject.org)
[![Cockpit](https://img.shields.io/badge/Cockpit-Native-navy.svg)](https://cockpit-project.org)
[![Zoraxy](https://img.shields.io/badge/Zoraxy-Proxy-teal.svg)](https://zoraxy.arozos.com)
[![SFTPGo](https://img.shields.io/badge/SFTPGo-Storage-orange.svg)](https://sftpgo.com)

---

## ⚡ Installation Rapide (1 seule commande)

Connectez-vous à votre VPS en SSH et exécutez la commande suivante :

```bash
git clone https://github.com/guomangu/iVPS.git && cd iVPS && ./install.sh
```

> [!NOTE]
> Le script installe les dépendances requises, configure les ports rootless, génère les règles de proxy, active le pare-feu et lance la stack en tâche de fond persistante.

---

## 🏗️ Architecture et Flux Réseau

```text
[ Internet : 80 / 443 ] ──► Zoraxy Reverse Proxy (Podman Rootless)
                               ├── admin.domaine.com (+ racine) ──► Cockpit Console OS (:9090)
                               ├── proxy.domaine.com            ──► Zoraxy Admin Web (:8000)
                               ├── folder.domaine.com           ──► SFTPGo Web (:8080)
                               └── Domaine racine / landing     ──► Portail d'accueil IVPS
[ Internet : 2022 ]    ────────────────────────────────────────► SFTPGo Serveur SFTP
```

---

## 🛡️ Fonctionnalités Clés & Robustesse

- **Routage Automatisé (Zero-Conf)** : Les règles de proxy JSON pour Zoraxy (`proxy.*`, `admin.*`, `folder.*`) sont générées dès l'installation : **aucun paramétrage manuel préalable n'est nécessaire**.
- **Portail d'Accueil Inclus** : Le domaine racine (`https://votre-domaine.com`) héberge un tableau de bord responsive avec boutons d'accès direct vers vos 3 interfaces d'administration.
- **Support Podman Rootless & SELinux** :
  - Volumes montés avec les drapeaux `:Z,U` pour adapter la propriété aux conteneurs non-privilégiés.
  - Permissions récursives gérées avec `podman unshare` pour aligner les sous-UIDs (ex: UID `1000:1000` interne de SFTPGo) sans erreur de permission sur l'hôte.
- **Allocation Dynamique & Idempotente des Ports** :
  - Arrêt temporaire propre lors des ré-exécutions pour éviter les collisions avec ses propres conteneurs.
  - Rétablissement automatique des ports standards (`8000`, `8080`, `2022`) dès qu'ils sont libres.
  - Port natif de Cockpit verrouillé sur son écoute réelle (**`9090`**).
- **Mot de Passe Maître Centralisé** : Généré aléatoirement ou personnalisable dans [`.env`](file:///home/gamo/Documents/ivps/.env) avec réapplication immédiate via `./install.sh`.
- **Persistance Systemd (Linger)** : Service `systemd --user` (`ivps-stack.service`) activé avec `loginctl enable-linger` pour démarrer dès le boot du VPS sans session interactive ouverte.
- **Pare-feu Automatique** : Configuration persistante pour **Firewalld** (Fedora/RHEL) et **UFW** (Debian/Ubuntu).

---

## ⚙️ Configuration Rapide (`.env`)

Toutes les variables sont ajustables dans le fichier `.env` à la racine du projet :

```dotenv
# Nom de domaine principal (pointant vers l'IP de votre serveur)
DOMAIN_NAME=votre-domaine.com

# Sous-domaines personnalisables
ZORAXY_SUBDOMAIN=proxy
COCKPIT_SUBDOMAIN=admin
SFTPGO_SUBDOMAIN=folder

# Mot de passe maître (laissez vide pour auto-génération sécurisée)
ADMIN_PASSWORD=

# Ports d'écoute personnalisables (ajustés dynamiquement en cas de conflit)
ZORAXY_HTTP_PORT=80
ZORAXY_HTTPS_PORT=443
ZORAXY_ADMIN_PORT=8000
SFTPGO_WEB_PORT=8080
SFTPGO_SFTP_PORT=2022
COCKPIT_PORT=9090

# Réseau et stockage
DATA_DIR=./data
PODMAN_NETWORK=ivps-net
ENABLE_UNPRIVILEGED_PORTS=true
TZ=UTC
```

---

## 🌐 Points d'Accès

| Service | Interface | URL Dédiée | Port Hôte Direct | Identifiants par défaut |
|---|---|---|---|---|
| **Portail IVPS** | Page d'accueil | `https://domaine.com` | `:80 / :443` | — |
| **Cockpit** | Console OS & Terminal | `https://admin.domaine.com` | `:9090` | Utilisateur Linux hôte (ex: `fedora`) |
| **Zoraxy** | Reverse Proxy & WAF | `https://proxy.domaine.com` | `:8000` | `admin` / `<ADMIN_PASSWORD>` |
| **SFTPGo Web** | Gestionnaire Fichiers | `https://folder.domaine.com` | `:8080` | `admin` / `<ADMIN_PASSWORD>` |
| **Serveur SFTP** | FileZilla / VS Code | `sftp://admin@<IP>:2022` | `:2022` | `admin` / `<ADMIN_PASSWORD>` |

---

## 🔒 Activation du Certificat SSL (HTTPS)

Une fois vos sous-domaines configurés dans votre zone DNS :
1. Connectez-vous sur **Zoraxy Web Admin** (`https://proxy.domaine.com` ou `http://<IP>:8000`).
2. Rendez-vous dans **TLS / SSL** > **ACME (Let's Encrypt)**.
3. Renseignez votre adresse e-mail de contact.
4. Activez l'émission automatique des certificats SSL pour vos domaines et cochez **HTTP to HTTPS Redirection**.

---

## 🛠️ Exploitation & Commandes Utiles

```bash
# Appliquer ou synchroniser les modifications du .env
./install.sh

# Consulter l'état des conteneurs
systemctl --user status ivps-stack.service

# Suivre les journaux d'exécution en direct
journalctl --user -u ivps-stack.service -f

# Redémarrer la stack Podman
systemctl --user restart ivps-stack.service

# Inspecter les conteneurs actifs
podman ps

# Accéder au shell dans le namespace Podman rootless (dépannage permissions)
podman unshare ls -la ./data/sftpgo/data

# Désinstaller la stack proprement (--purge pour effacer les données ./data)
./uninstall.sh
```

---

## 📂 Structure du Répertoire

```text
├── install.sh                  # Orchestrateur d'installation et synchronisation
├── uninstall.sh                # Script de désinstallation propre
├── compose.yaml                # Définition multi-conteneurs Podman
├── .env.example                # Modèle des variables d'environnement
├── Architecture de la Stack VPS.md # Documentation d'architecture détaillée
├── containers/                 # Configurations spécifiques des conteneurs
│   ├── zoraxy/
│   └── sftpgo/
└── scripts/                    # Scripts modulaires (< 100 lignes)
    ├── common.sh               # Fonctions partagées, ports et logs
    ├── 01_install_deps.sh      # Installation des paquets système (dnf, apt, etc.)
    ├── 02_install_components.sh# Stockage, ports dynamiques et Podman
    ├── 03_configure.sh         # Cockpit.conf et pare-feu (Firewalld/UFW)
    ├── 03_zoraxy_rules.sh      # Pré-configuration des règles JSON de Zoraxy
    ├── 04_systemd_linger.sh    # Déploiement de l'unité systemd --user
    └── 05_uninstall.sh         # Nettoyage et suppression
```
