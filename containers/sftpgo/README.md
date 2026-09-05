# SFTPGo - Gestionnaire de Fichiers Web & SFTP

[SFTPGo](https://sftpgo.com/) fournit un serveur SFTP robuste et une interface web moderne de gestion de fichiers.

## Authentification et Synchronisation Centralisée

- **Compte Administrateur Unique** :
  - Identifiant universel : Défini par `ADMIN_USER` dans le fichier `.env` (synchronisé avec l'utilisateur système hôte ou `admin`).
  - Mot de passe : Synchronisé avec `ADMIN_PASSWORD` défini dans le fichier `.env`.
- **Double Rôle Automatisé** :
  - **WebAdmin** (`/web/admin`) : Gestion complète des partages, quotas, protocoles et utilisateurs.
  - **WebClient** (`https://folder.votre-domaine.com` ou direct `:8080`) : Explorateur de fichiers interactif dans le navigateur avec upload/download glisser-déposer.
  - **Serveur SFTP** (`sftp://<ADMIN_USER>@<IP>:2022`) : Connexion directe pour FileZilla, VS Code, Cyberduck avec accès complet au stockage partagé.
- **Chroot & Isolation Rootless** : Les utilisateurs de fichiers SFTPGo n'ont aucun compte shell système Unix non restreint sur le serveur VPS hôte.

## Ports et Stockage

| Protocole | Port Externe | Volume Hôte | Usage |
|---|---|---|---|
| **Web UI** | `:8080` (dynamique) | `data/sftpgo/data` | Données internes et base SQLite |
| **SFTP** | `:2022` (dynamique) | `data/sftpgo/srv` | Répertoire partagé des fichiers |

## Reconfiguration de l'Utilisateur ou du Mot de Passe

Pour modifier les identifiants d'administration centraux :
1. Modifiez la variable `ADMIN_USER` et/ou `ADMIN_PASSWORD` dans `.env`.
2. Relancez `./install.sh` (ou `bash install.sh`) pour synchroniser automatiquement l'ensemble des accès.
