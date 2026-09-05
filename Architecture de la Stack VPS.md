# **Stack d'Administration VPS : Zoraxy + Cockpit + SFTPGo**

Cette stack hybride (mixant installation native et conteneurs Podman rootless) offre un équilibre parfait entre **sécurité**, **facilité d'utilisation** (interfaces web automatisées) et **puissance d'administration**.

---

## **1. L'Architecture Globale (Le Flux)**

```text
                                 ┌───────────────────────────────────────────────────────────┐
                                 │                    INTERNET                               │
                                 └─────────────────────┬─────────────────────────────────────┘
                                                       │
                                  Ports 80 / 443 (TCP) │
                                                       ▼
                                 ┌───────────────────────────────────────────────────────────┐
                                 │                    ZORAXY (Reverse Proxy & WAF)           │
                                 │                 Conteneur Podman Rootless                 │
                                 │        Ports d'écoute hôte : 80, 443, Admin : 8000        │
                                 └──────────────┬──────────────────┬──────────────────┬──────┘
                                                │                  │                  │
               https://admin.votre-domaine.com  │                  │                  │ https://folder.votre-domaine.com
                                                ▼                  │                  ▼
                                 ┌─────────────────────┐           │           ┌─────────────────────┐
                                 │  Cockpit Console OS │           │           │     SFTPGo Web      │
                                 │   (Service Natif)   │           │           │     (Port 8080)     │
                                 │     (Port 9090)     │           │           └─────────────────────┘
                                 └─────────────────────┘           │                      ▲
                                                                   ▼                      │
                                                        https://proxy.votre-domaine.com   │
                                                        ┌─────────────────────┐           │
                                                        │  Zoraxy Web Admin   │           │
                                                        │     (Port 8000)     │           │
                                                        └─────────────────────┘           │
                                                                                          │
                                 Port 2022 Direct (SFTP)                                  │
                                 ─────────────────────────────────────────────────────────┘
```

### Flux d'Exécution
1. **Point d'entrée unique** : Internet contacte votre serveur exclusivement sur les ports **80** (HTTP) et **443** (HTTPS).
2. **Filtrage et Chiffrement** : **Zoraxy** intercepte toutes les requêtes, gère le chiffrement SSL/TLS (Let's Encrypt automatique) et bloque les attaques via son WAF intégré.
3. **Routage Automatique par Sous-Domaine (Zero-Conf)** : Zoraxy dispatche instantanément vers le service approprié grâce aux règles générées dès l'installation :
   * `admin.votre-domaine.com` ➔ **Cockpit** (`http://host.containers.internal:9090` avec support WebSockets).
   * `proxy.votre-domaine.com` ➔ **Zoraxy Web Admin** (`http://127.0.0.1:8000`).
   * `folder.votre-domaine.com` ➔ **SFTPGo Web** (`http://ivps-sftpgo:8080`).
   * `*.votre-domaine.com` ➔ N'importe quelle future application conteneurisée.
4. **Transfert de fichiers SFTP Direct** : Le port **2022** est exposé directement pour les clients SFTP (FileZilla, Cyberduck, VS Code).
5. **Authentification Unifiée dès la Première Connexion** :
   * Aucun portail public non filtré sur le domaine racine.
   * L'accès à chaque interface sollicite immédiatement les identifiants centraux définis dans le `.env` (`ADMIN_USER` / `ADMIN_PASSWORD`).

---

## **2. Cockpit : La Tour de Contrôle (Installation Native)**

Contrairement aux applications conteneurisées, Cockpit s'installe **directement sur le système d'exploitation** de votre VPS (Fedora, RHEL, Debian, Ubuntu).

### Points forts techniques
* **Consommation Zéro au repos** : Activé à la demande par socket Systemd (`cockpit.socket`), il ne consomme aucune ressource CPU/RAM en veille.
* **Synchronisation avec Utilisateur Hôte** : Le script détecte et synchronise l'utilisateur spécifié dans `ADMIN_USER` (utilisateur natif existant du VPS ou nouveau compte), lui accorde les privilèges d'administration (`wheel`/`sudo`) et synchronise le mot de passe maître.
* **cockpit-podman** : Gestion visuelle complète des conteneurs, images, réseaux et volumes Podman rootless.
* **cockpit-storaged** : Surveillance des disques, partitionnement et santé SMART.
* **cockpit-pcp (Performance Co-Pilot)** : Historique des métriques (CPU, RAM, E/S, Réseau) sur plusieurs jours/semaines.

---

## **3. Zoraxy : Le Routeur, Vigile & WAF (Conteneur Podman Rootless)**

Zoraxy est votre **Reverse Proxy & WAF**. C'est le bouclier réseau de votre infrastructure.

### Fonctionnalités Clés & Gestion de l'Authentification
* **Routage Zero-Conf** : Le script `scripts/03_zoraxy_rules.sh` écrit directement les fichiers de règles au format JSON dans `conf/proxy/`. L'accès est fonctionnel dès la première minute.
* **Séparation Stockage (`conf/` vs `sys.db`)** :
  - `conf/` : Héberge la configuration réseau, les certificats SSL et les règles de proxy sous forme de fichiers JSON persistants.
  - `sys.db` : Base embarquée BoltDB contenant les sessions d'administration et les métriques de trafic.
* **Auto-Guérison et Synchronisation Continue** :
  - Lors de chaque exécution de `./install.sh`, le script teste activement l'authentification (`POST /api/auth/login`) avec les identifiants déclarés dans `.env`.
  - **Identifiants inchangés** : Aucune coupure, les sessions et métriques sont conservées.
  - **Identifiants modifiés ou non alignés** : Zoraxy est réinitialisé automatiquement (purge de `sys.db` sans affecter les règles `conf/`), redémarré et réinscrit instantanément avec les nouveaux identifiants `ADMIN_USER` et `ADMIN_PASSWORD`.
* **Gestionnaire ACME / SSL** : Certificats Let's Encrypt générés et renouvelés automatiquement avec redirection HTTPS forcée.
* **WAF & Filtrage GeoIP** : Blocage d'adresses IP agressives, limitation de débit (rate limiting) et restriction géographique par pays.
* **Isolation Rootless & Ports Privilégiés** : Zoraxy tourne sans privilèges root grâce à la directive sysctl `net.ipv4.ip_unprivileged_port_start=80`.

---

## **4. SFTPGo : Le Gestionnaire de Fichiers & SFTP (Conteneur Podman Rootless)**

SFTPGo remplace avantageusement les serveurs FTP/SFTP traditionnels en combinant interface web et accès SFTP haute sécurité.

### Gestion avancée des permissions sous Podman Rootless
* **Le défi des subUIDs** : Dans un conteneur rootless, SFTPGo s'exécute avec son propre UID interne non privilégié (`UID 1000:GID 1000`), qui correspond sur l'hôte à un sous-identifiant (ex: `UID 100999`).
* **La solution de la Stack** : Utilisation conjointe du flag de volume `:Z,U` et de `podman unshare chown -R 1000:1000 data/sftpgo/srv` pour garantir des droits d'écriture sans restriction.
* **Double Synchronisation des Comptes** : Le script configure `ADMIN_USER` à la fois comme super-administrateur WebAdmin et comme utilisateur WebClient / serveur SFTP (port 2022).

---

## **5. Tableau Récapitulatif de la Stack**

| Service | Mode d'installation | Rôle | URL d'accès | Port direct hôte | Identifiant maître |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Zoraxy** | Conteneur Podman rootless | Reverse Proxy & WAF | `https://proxy.votre-domaine.com` | `8000` | `<ADMIN_USER>` / `<MDP_ENV>` |
| **Cockpit** | Natif OS (systemd socket) | Administration Système | `https://admin.votre-domaine.com` | `9090` | `<ADMIN_USER>` / `<MDP_ENV>` |
| **SFTPGo Web** | Conteneur Podman rootless | Gestionnaire Fichiers Web | `https://folder.votre-domaine.com` | `8080` | `<ADMIN_USER>` / `<MDP_ENV>` |
| **SFTPGo SFTP**| Conteneur Podman rootless | Transfert SFTP sécurisé | `sftp://<ADMIN_USER>@<IP-SERVEUR>:2022` | `2022` | `<ADMIN_USER>` / `<MDP_ENV>` |

---

## **6. Scénario d'Utilisation Réel**

```bash
# 1. Se connecter à la console Cockpit pour inspecter les métriques
# Rendez-vous sur : https://admin.votre-domaine.com

# 2. Transférer des fichiers applicatifs (ex: compose.yaml)
sftp -P 2022 <ADMIN_USER>@<IP-SERVEUR>

# 3. Gérer les certificats SSL Let's Encrypt et le WAF
# Rendez-vous sur : https://proxy.votre-domaine.com

# 4. Mettre à jour les identifiants ou reconfigurer
nano .env
./install.sh
```
