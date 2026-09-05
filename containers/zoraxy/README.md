# Zoraxy - Reverse Proxy & Sécurité

[Zoraxy](https://zoraxy.arozos.com/) est le point d'entrée HTTP/HTTPS unique pour tous les services hébergés sur le VPS.

## Rôle et Fonctionnalités

- **Reverse Proxy HTTP/HTTPS** : Écoute sur les ports 80 et 443.
- **Certificats SSL automatisés** : Gestion ACME intégrée via Let's Encrypt.
- **WAF & Filtrage IP** : Pare-feu applicatif web, blocage par géolocalisation et anti-bruteforce.
- **Interface Web intuitive** : Accessible lors du premier démarrage sur le port `8000`.

## Configuration du Routage

Une fois connecté à l'interface d'administration de Zoraxy (`http://<IP-SERVEUR>:8000`) :
1. **Règle Cockpit** :
   - Sous-domaine : `admin.votre-domaine.com`
   - Cible : `http://host.containers.internal:9090` (ou `http://127.0.0.1:9090`)
   - Activer : Support **WebSocket**
2. **Règle SFTPGo** :
   - Sous-domaine : `fichiers.votre-domaine.com`
   - Cible : `http://ivps-sftpgo:8080`
