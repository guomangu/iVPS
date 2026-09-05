# Zoraxy - Reverse Proxy, WAF & Sécurité

[Zoraxy](https://zoraxy.arozos.com/) sert de point d'entrée HTTP/HTTPS unique pour tous les services de la stack VPS.

## Interfaces et Routage

| Domaine Cible | Destination Interne | Options Requises |
|---|---|---|
| `proxy.votre-domaine.com` | `http://127.0.0.1:8000` | Accès interface Zoraxy |
| `admin.votre-domaine.com` | `http://host.containers.internal:9090` | Activer WebSocket (Cockpit) |
| `folder.votre-domaine.com` | `http://ivps-sftpgo:8080` | Interface Web SFTPGo |

## Configuration Initiale

1. Les règles de reverse proxy sont générées automatiquement par le script d'installation (`install.sh`).
2. Le compte administrateur `admin` est initialisé automatiquement avec le mot de passe défini dans `.env` (`ADMIN_PASSWORD`).
3. Activez la génération de certificats SSL Let's Encrypt d'un simple clic par sous-domaine depuis l'interface Zoraxy.

## Fonctionnalités Avancées
- **WAF intégré** : Blocage de requêtes malveillantes et limitation de débit (rate limiting).
- **Gestionnaire GeoIP** : Autorisation ou blocage sélectif par pays.
