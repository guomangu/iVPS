# Zoraxy - Reverse Proxy, WAF & Sécurité

[Zoraxy](https://zoraxy.arozos.com/) sert de point d'entrée HTTP/HTTPS unique pour tous les services de la stack VPS.

## Interfaces et Routage

| Domaine Cible | Destination Interne | Options Requises |
|---|---|---|
| `proxy.votre-domaine.com` | `http://127.0.0.1:8000` | Accès interface Zoraxy |
| `admin.votre-domaine.com` | `http://host.containers.internal:9090` | Activer WebSocket (Cockpit) |
| `folder.votre-domaine.com` | `http://ivps-sftpgo:8080` | Interface Web SFTPGo |

## Configuration Initiale & Gestion des Accès

1. **Routage Automatisé** : Les règles de reverse proxy sont générées automatiquement par le script d'installation (`install.sh`) dans `conf/proxy/`.
2. **Synchronisation d'Identifiants & Auto-Guérison** : Le compte administrateur est initialisé et synchronisé automatiquement avec `ADMIN_USER` et `ADMIN_PASSWORD` déclarés dans `.env`.
3. **Séparation des Données** :
   - `conf/` : Fichiers JSON de routage, certificats SSL et configurations de proxy (toujours préservés).
   - `sys.db` : Base BoltDB interne pour les comptes et statistiques. Si vous modifiez `ADMIN_USER` ou `ADMIN_PASSWORD` dans `.env`, `install.sh` réinitialise automatiquement `sys.db` sans impacter vos règles de routage.
4. **Certificats SSL** : Activez la génération de certificats Let's Encrypt d'un simple clic par sous-domaine depuis l'interface Zoraxy.

## Fonctionnalités Avancées
- **WAF intégré** : Blocage de requêtes malveillantes et limitation de débit (rate limiting).
- **Gestionnaire GeoIP** : Autorisation ou blocage sélectif par pays.
