# IVPS Stack : Zoraxy + Cockpit + SFTPGo

Stack d'administration VPS moderne, conteneurisée et prête pour la production (**Fedora**, **RHEL**, **Debian**, **Ubuntu**). Elle associe **Cockpit** (gestion OS native), **Podman rootless** avec **Zoraxy** (Reverse Proxy & WAF) et **SFTPGo** (Fichiers & SFTP).

[![Podman](https://img.shields.io/badge/Podman-Rootless-purple.svg)](https://podman.io)
[![Fedora](https://img.shields.io/badge/Fedora-Ready-blue.svg)](https://fedoraproject.org)
[![Cockpit](https://img.shields.io/badge/Cockpit-Native-navy.svg)](https://cockpit-project.org)
[![Zoraxy](https://img.shields.io/badge/Zoraxy-Proxy-teal.svg)](https://zoraxy.arozos.com)
[![SFTPGo](https://img.shields.io/badge/SFTPGo-Storage-orange.svg)](https://sftpgo.com)

---

## ⚡ Installation Rapide (1 seule commande)

Copiez-collez cette commande dans votre terminal VPS pour cloner et lancer l'installation :

```bash
git clone https://github.com/guomangu/iVPS.git && cd iVPS && ./install.sh
```

---

## 🏗️ Architecture et Flux Réseau

```text
[ Internet : 80 / 443 ] ──► Zoraxy Reverse Proxy (Podman Rootless)
                               ├── proxy.domaine.com    ──► Zoraxy Admin (:8000)
                               ├── admin.domaine.com    ──► Cockpit (:9090)
                               ├── fichiers.domaine.com ──► SFTPGo Web (:8080)
                               └── SFTP Direct (:2022)  ──► SFTPGo Serveur
```

---

## 🛡️ Fonctionnalités Clés & Robustesse

- **Optimisé Fedora / RHEL** : Détection DNF, règles Firewalld persistantes et étiquetage SELinux (`:Z`, `container_file_t`).
- **Ports Dynamiques** : Détection automatique des ports occupés et réattribution sans conflit.
- **Mot de Passe Centralisé** : Généré aléatoirement ou personnalisable dans [`.env`](file:///home/gamo/Documents/ivps/.env) avec prise en compte instantanée en rejouant `./install.sh`.
- **Zoraxy Dédié** : Sous-domaine dédié (`proxy.votre-domaine.com`) pour une administration 100% chiffrée.
- **Systemd Linger** : Démarrage automatique au boot sans session interactive ouverte.

---

## ⚙️ Configuration Rapide (`.env`)

```dotenv
DOMAIN_NAME=votre-domaine.com
ZORAXY_SUBDOMAIN=proxy
COCKPIT_SUBDOMAIN=admin
SFTPGO_SUBDOMAIN=fichiers
ADMIN_PASSWORD=             # Laissez vide pour auto-génération
```

---

## 🌐 Points d'Accès

| Service | Interface | URL / Port |
|---|---|---|
| **Zoraxy Proxy** | Web UI | `https://proxy.domaine.com` (ou port `:8000`) |
| **Cockpit** | Web Console | `https://admin.domaine.com` (ou port `:9090`) |
| **SFTPGo Web** | Gestionnaire Fichiers | `https://fichiers.domaine.com` (ou port `:8080`) |
| **Serveur SFTP** | Client SFTP | `sftp://admin@<IP>:2022` |

---

## 🛠️ Exploitation & Maintenance

```bash
./install.sh                                # Appliquer les modifications du .env
systemctl --user status ivps-stack.service  # Consulter le statut des conteneurs
journalctl --user -u ivps-stack.service -f  # Suivre les journaux d'exécution
./uninstall.sh                              # Désinstaller proprement (--purge pour effacer data/)
```
