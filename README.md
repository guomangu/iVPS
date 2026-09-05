# IVPS Stack : Zoraxy + Cockpit + SFTPGo

Stack d'administration VPS moderne, sécurisée et conteneurisée combinant la puissance native de **Cockpit** et la flexibilité de **Podman rootless** avec **Zoraxy** (Reverse Proxy & WAF) et **SFTPGo** (Fichiers Web & SFTP).

[![Podman](https://img.shields.io/badge/Podman-Rootless-purple.svg)](https://podman.io)
[![Cockpit](https://img.shields.io/badge/Cockpit-Native-blue.svg)](https://cockpit-project.org)
[![Zoraxy](https://img.shields.io/badge/Zoraxy-Proxy-teal.svg)](https://zoraxy.arozos.com)
[![SFTPGo](https://img.shields.io/badge/SFTPGo-Storage-orange.svg)](https://sftpgo.com)

---

## ⚡ Installation Rapide (1 seule commande)

Copiez-collez cette commande dans votre terminal VPS pour cloner et lancer l'installation :

```bash
git clone https://github.com/USER/ivps.git && cd ivps && ./install.sh
```

---

## 🏗️ Architecture des Composants

```text
[ Internet : 80 / 443 ]
          │
    ▼ [ Zoraxy Reverse Proxy (Podman) ] 
          ├── admin.domaine.com    ──► Cockpit (Natif : 9090 via socket)
          ├── fichiers.domaine.com ──► SFTPGo Web (:8080)
          └── SFTP Direct (:2022)  ──► SFTPGo SFTP Server
```

- **Cockpit (Natif)** : Supervision système, métriques pcp, disques, mises à jour et cockpit-podman.
- **Zoraxy (Podman)** : Reverse proxy unique exposé, certificats Let's Encrypt auto, WAF et filtrage IP.
- **SFTPGo (Podman)** : Explorateur de fichiers Web moderne et serveur SFTP isolé en chroot.
- **Systemd Linger** : Démarre automatiquement la stack utilisateur au boot sans session active.

---

## ⚙️ Configuration (`.env`)

Toutes les variables sont personnalisables dans le fichier [`.env`](file:///home/gamo/Documents/ivps/.env) :

```dotenv
DOMAIN_NAME=votre-domaine.com
COCKPIT_SUBDOMAIN=admin
SFTPGO_SUBDOMAIN=fichiers
ZORAXY_HTTP_PORT=80
ZORAXY_HTTPS_PORT=443
SFTPGO_SFTP_PORT=2022
```

---

## 🌐 Points d'Accès

| Service | Interface | Adresse par défaut |
|---|---|---|
| **Zoraxy Setup** | Web UI | `http://<IP-SERVEUR>:8000` |
| **Cockpit** | Web Console | `https://admin.votre-domaine.com` (ou port `9090`) |
| **SFTPGo Web** | Web Manager | `https://fichiers.votre-domaine.com` (ou port `8080`) |
| **Serveur SFTP** | SFTP Client | `sftp://<IP-SERVEUR>:2022` |

---

## 🛠️ Commandes Utiles

```bash
systemctl --user status ivps-stack.service  # État de la stack conteneurs
journalctl --user -u ivps-stack.service -f  # Logs en direct
./uninstall.sh                              # Désinstaller proprement
./uninstall.sh --purge                      # Désinstaller et purger les données
```

Pour plus de détails, consultez [scripts/README.md](file:///home/gamo/Documents/ivps/scripts/README.md) et [containers/README.md](file:///home/gamo/Documents/ivps/containers/README.md).
