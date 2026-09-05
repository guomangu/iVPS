# IVPS Stack : Zoraxy + Cockpit + SFTPGo

Stack d'administration VPS moderne, entièrement conteneurisée et prête pour la production (**Fedora**, **RHEL**, **Debian**, **Ubuntu**). Elle associe **Cockpit** (gestion OS native), **Podman rootless** avec **Zoraxy** (Reverse Proxy, WAF & SSL) et **SFTPGo** (Explorateur Web & SFTP).

[![Podman](https://img.shields.io/badge/Podman-Rootless-purple.svg)](https://podman.io)
[![Fedora](https://img.shields.io/badge/Fedora-Ready-blue.svg)](https://fedoraproject.org)
[![Cockpit](https://img.shields.io/badge/Cockpit-Native-navy.svg)](https://cockpit-project.org)
[![Zoraxy](https://img.shields.io/badge/Zoraxy-Proxy-teal.svg)](https://zoraxy.arozos.com)
[![SFTPGo](https://img.shields.io/badge/SFTPGo-Storage-orange.svg)](https://sftpgo.com)

---

## ⚡ Installation Rapide (1 seule commande)

Copiez-collez cette commande dans votre terminal VPS pour cloner et lancer l'installation automatisée :

```bash
git clone https://github.com/guomangu/iVPS.git && cd iVPS && ./install.sh
```

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
- **Portail d'Accueil Inclus** : Le domaine racine (`https://votre-domaine.com`) propose une page d'accueil sombre et épurée avec liens directs vers vos 3 consoles d'administration.
- **Support Podman Rootless & SELinux** : Volumes montés avec options `:Z,U` et adaptation des droits UID subuid (`1000:1000`) pour SFTPGo, évitant tout blocage de permission SQLite sous Fedora/RHEL.
- **Allocation Dynamique des Ports** : En cas de port déjà utilisé (ex: 8000 ou 9090), le script réattribue automatiquement un port disponible et met à jour le fichier `.env`.
- **Mot de Passe Maître Centralisé** : Généré aléatoirement ou personnalisable dans [`.env`](file:///home/gamo/Documents/ivps/.env) avec réapplication immédiate via `./install.sh`.
- **Persistance Systemd (Linger)** : Service `systemd --user` (`ivps-stack.service`) activé avec `loginctl enable-linger` pour démarrer dès le boot de la machine sans session active.
- **Pare-feu Automatique** : Configuration persistante pour **Firewalld** (Fedora/RHEL) et **UFW** (Debian/Ubuntu).

---

## ⚙️ Configuration Rapide (`.env`)

```dotenv
# Nom de domaine principal
DOMAIN_NAME=votre-domaine.com

# Sous-domaines d'accès
ZORAXY_SUBDOMAIN=proxy
COCKPIT_SUBDOMAIN=admin
SFTPGO_SUBDOMAIN=folder

# Mot de passe centralisé (laissez vide pour génération aléatoire sécurisée)
ADMIN_PASSWORD=
```

---

## 🌐 Points d'Accès

| Service | Interface | URL Dédiée | Port Hôte Direct |
|---|---|---|---|
| **Portail IVPS** | Page d'accueil | `https://domaine.com` | `:80 / :443` |
| **Cockpit** | Console OS & Web Terminal | `https://admin.domaine.com` | `:9090` |
| **Zoraxy** | Reverse Proxy & WAF | `https://proxy.domaine.com` | `:8000` |
| **SFTPGo Web** | Gestionnaire Fichiers | `https://folder.domaine.com` | `:8080` |
| **Serveur SFTP** | FileZilla / VS Code | `sftp://admin@<IP-SERVEUR>:2022` | `:2022` |

---

## 🛠️ Exploitation & Maintenance

```bash
# Appliquer ou synchroniser les changements du .env
./install.sh

# Consulter l'état des conteneurs
systemctl --user status ivps-stack.service

# Suivre les journaux d'exécution en temps réel
journalctl --user -u ivps-stack.service -f

# Redémarrer la stack
systemctl --user restart ivps-stack.service

# Désinstaller proprement (--purge pour supprimer aussi le dossier data/)
./uninstall.sh
```
