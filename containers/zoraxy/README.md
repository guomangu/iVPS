# Zoraxy - Reverse Proxy, WAF & Sécurité

[Zoraxy](https://zoraxy.arozos.com/) sert de point d'entrée HTTP/HTTPS unique pour tous les services de la stack VPS.

## Interfaces et Routage

| Domaine Cible | Destination Interne | Options Requises |
|---|---|---|
| `proxy.votre-domaine.com` | `http://127.0.0.1:8000` | Accès interface Zoraxy |
| `admin.votre-domaine.com` | `http://host.containers.internal:9090` | Activer WebSocket (Cockpit) |
| `fichiers.votre-domaine.com` | `http://ivps-sftpgo:8080` | Interface Web SFTPGo |

## Configuration Initiale

1. Connectez-vous sur le port d'administration initial : `http://<IP-SERVEUR>:8000`.
2. Définissez le mot de passe maître (celui indiqué dans votre `.env` à la variable `ADMIN_PASSWORD`).
3. Créez les 3 règles de routage ci-dessus.
4. Activez la génération de certificats SSL Let's Encrypt d'un simple clic par sous-domaine.

## Fonctionnalités Avancées
- **WAF intégré** : Blocage de requêtes malveillantes et limitation de débit (rate limiting).
- **Gestionnaire GeoIP** : Autorisation ou blocage sélectif par pays.
