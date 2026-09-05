# SFTPGo - Gestionnaire de Fichiers & SFTP

[SFTPGo](https://sftpgo.com/) fournit un serveur SFTP robuste et une interface web moderne de gestion de fichiers.

## Authentification et Sécurité

- **Compte Administrateur Automatisé** :
  - Identifiant : `admin`
  - Mot de passe : Synchronisé avec `ADMIN_PASSWORD` défini dans le fichier `.env`.
- **Chroot & Isolation** : Les utilisateurs créés n'ont aucun compte système Unix sur le VPS hôte.

## Ports et Stockage

| Protocole | Port Externe | Volume Hôte | Usage |
|---|---|---|---|
| **Web UI** | `:8080` (dynamique) | `data/sftpgo/data` | Données internes et base SQLite |
| **SFTP** | `:2022` (dynamique) | `data/sftpgo/srv` | Répertoire partagé des fichiers |

## Reconfiguration du Mot de Passe

Pour modifier le mot de passe d'administration central :
1. Modifiez la variable `ADMIN_PASSWORD` dans `.env`.
2. Relancez `./install.sh` pour actualiser l'environnement du conteneur.
