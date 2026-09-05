# SFTPGo - Gestionnaire de Fichiers & SFTP

[SFTPGo](https://sftpgo.com/) gère le transfert de fichiers et le stockage du VPS.

## Rôle et Fonctionnalités

- **Interface Web Client** : Explorateur de fichiers complet via navigateur web (`:8080`).
- **Serveur SFTP** : Écoute sur le port `:2022` pour les clients comme FileZilla, Cyberduck ou VS Code.
- **Gestion des utilisateurs virtuels** : Création d'utilisateurs isolés (chroot) sans créer de comptes système Linux.
- **Volumes de données** :
  - `data/sftpgo/data` : Base de données interne et configurations de SFTPGo.
  - `data/sftpgo/srv` : Répertoire racine des données transférées.

## Premier Démarrage

Lors de la première connexion à l'interface SFTPGo :
1. Créez le compte administrateur principal.
2. Créez un dossier virtuel pointant vers `/srv/sftpgo`.
3. Ajoutez vos comptes utilisateurs (ex: développeur, sauvegarde).
