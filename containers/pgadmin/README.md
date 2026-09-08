# pgAdmin 4 - Gestionnaire de base de données Web

[pgAdmin 4](https://www.pgadmin.org/) est l'interface web officielle et moderne d'administration pour PostgreSQL.

## Déploiement Rootless & Mode Host

pgAdmin s'exécute directement sur la pile réseau de l'hôte (`--network host`) en utilisant des privilèges restreints (Rootless). Cela permet :
- **Sécurité** : Processus isolé de l'hôte, ne nécessitant pas de droits root.
- **Performances** : Pas de traduction NAT requise pour la gestion des données localement.

## Points de Montage (Volumes)

| Service | Port par défaut | Chemin Local | Contenu |
|---|---|---|---|
| **Web UI** | `:5050` (dynamique) | `data/pgadmin` | Configuration, sessions et données internes |

## Intégration dans la Stack IVPS

Dans l'écosystème IVPS, pgAdmin est configuré de façon unifiée :
1. **Authentification Globale** : Identité alignée avec Cockpit. `PGADMIN_DEFAULT_EMAIL` prend la valeur de `ADMIN_USER` avec le suffixe du nom de domaine, et le mot de passe correspond à `ADMIN_PASSWORD`.
2. **Accessibilité** : Expose de base le port `5050`. Zoraxy achemine en toute sécurité le sous-domaine affecté (ex: `db.votre-domaine.com`) vers le port d'écoute pgAdmin via un tunnel chiffré SSL automatique, sans avoir à exposer le port `5050` publiquement sur internet.
