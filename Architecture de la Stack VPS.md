# **Stack d'Administration VPS : Zoraxy + Cockpit + SFTPGo**

Cette stack hybride (mixant installation native et conteneurs Podman rootless) offre un équilibre parfait entre **sécurité**, **facilité d'utilisation** (interfaces web automatisées) et **puissance d'administration**.

---

## **1. L'Architecture Globale (Le Flux)**

```text
                                 ┌───────────────────────────────────────────────────────────┐
                                 │                    INTERNET                               │
                                 └─────────────────────┬─────────────────────────────────────┘
                                                       │
                                  Ports 80 / 443 (HTTP/HTTPS)
                                                       │
                                                       ▼
                                 ┌───────────────────────────────────────────────────────────┐
                                 │             Zoraxy Reverse Proxy & WAF                    │
                                 │            (Conteneur Podman Rootless)                    │
                                 └──────────┬───────────────────┬───────────────────┬────────┘
                                            │                   │                   │
                  admin.domaine.com (+ racine)    proxy.domaine.com      folder.domaine.com
                                            │                   │                   │
                                            ▼                   ▼                   ▼
                                 ┌─────────────────────┐┌──────────────┐┌────────────────────┐
                                 │  Cockpit Console OS ││ Zoraxy Admin ││    SFTPGo Web      │
                                 │   (Service Natif)   ││  (Port 8000) ││   (Port 8080)      │
                                 │     (Port 9090)     ││              ││                    │
                                 └─────────────────────┘└──────────────┘└────────────────────┘
                                                                                    ▲
                                 Port 2022 Direct (SFTP)                            │
                                 ───────────────────────────────────────────────────┘
```

### Flux d'Exécution
1. **Point d'entrée unique** : Internet contacte votre serveur exclusivement sur les ports **80** (HTTP) et **443** (HTTPS).
2. **Filtrage et Chiffrement** : **Zoraxy** intercepte toutes les requêtes, gère le chiffrement SSL/TLS (Let's Encrypt automatique) et bloque les attaques via son WAF intégré.
3. **Routage Automatique (Zero-Conf)** : Zoraxy dispatche instantanément vers le service approprié grâce aux règles générées dès l'installation :
   * `admin.votre-domaine.com` (et domaine racine `votre-domaine.com`) ➔ **Cockpit** (`http://host.containers.internal:9090` avec support WebSockets).
   * `proxy.votre-domaine.com` ➔ **Zoraxy Web Admin** (`http://127.0.0.1:8000`).
   * `folder.votre-domaine.com` (ou `fichiers.*`) ➔ **SFTPGo Web** (`http://ivps-sftpgo:8080`).
   * `*.votre-domaine.com` ➔ N'importe quelle future application conteneurisée.
4. **Transfert de fichiers SFTP Direct** : Le port **2022** est exposé directement pour les clients SFTP (FileZilla, Cyberduck, VS Code).

---

## **2. Cockpit : La Tour de Contrôle (Installation Native)**

Contrairement aux applications conteneurisées, Cockpit s'installe **directement sur le système d'exploitation** de votre VPS (Fedora, RHEL, Debian, Ubuntu).

### Points forts techniques
* **Consommation Zéro au repos** : Activé à la demande par socket Systemd (`cockpit.socket`), il ne consomme aucune ressource CPU/RAM en veille.
* **cockpit-podman** : Gestion visuelle complète des conteneurs, images, réseaux et volumes Podman rootless.
* **cockpit-storaged** : Surveillance des disques, partitionnement et santé SMART.
* **cockpit-pcp (Performance Co-Pilot)** : Historique des métriques (CPU, RAM, E/S, Réseau) sur plusieurs jours/semaines.
* **cockpit-packagekit** : Maintenance et mises à jour de sécurité du système en 1 clic.
* **Terminal intégré** : Console Linux complète s'exécutant avec votre utilisateur système.
* **Origines WebSocket sécurisées** : Le script configure `/etc/cockpit/cockpit.conf` pour autoriser le proxying sans rejet d'origine WebSocket (`admin.domaine.com`, `domaine.com`).

---

## **3. Zoraxy : Le Routeur, Vigile & WAF (Conteneur Podman Rootless)**

Zoraxy est votre **Reverse Proxy & WAF**. C'est le bouclier réseau de votre infrastructure.

### Fonctionnalités Clés
* **Routage Zero-Conf** : Le script [`scripts/03_zoraxy_rules.sh`](file:///home/gamo/Documents/ivps/scripts/03_zoraxy_rules.sh) écrit directement les fichiers de règles au format JSON dans `conf/proxy/`. L'accès est fonctionnel dès la première minute.
* **Portail d'Accueil Personnalisé** : Le domaine racine héberge un tableau de bord sombre et responsive (`www/html/index.html`) avec des boutons d'accès rapide vers Cockpit, SFTPGo et Zoraxy.
* **Gestionnaire ACME / SSL** : Certificats Let's Encrypt générés et renouvelés automatiquement avec redirection HTTPS forcée.
* **WAF & Filtrage GeoIP** : Blocage d'adresses IP agressives, limitation de débit (rate limiting) et restriction géographique par pays.
* **Isolation Rootless & Ports Privilégiés** : Zoraxy tourne sans privilèges root grâce à la directive sysctl `net.ipv4.ip_unprivileged_port_start=80`.

---

## **4. SFTPGo : Le Gestionnaire de Fichiers & SFTP (Conteneur Podman Rootless)**

SFTPGo remplace avantageusement les serveurs FTP/SFTP traditionnels en combinant interface web et accès SFTP haute sécurité.

### Gestion avancée des permissions sous Podman Rootless
* **Le défi des subUIDs** : Dans un conteneur rootless, SFTPGo s'exécute avec son propre UID interne non privilégié (`UID 1000:GID 1000`), qui correspond sur l'hôte à un sous-identifiant (ex: `UID 100999`).
* **Montage de volume `:Z,U`** : L'option `:U` ordonne à Podman de translater récursivement les propriétaires du volume dans le user-namespace du conteneur.
* **Gestion native via `podman unshare`** : Les permissions et la propriété du dossier `./data/sftpgo` sont gérées via `podman unshare chown -R 1000:1000` et `podman unshare chmod -R 775`, garantissant que la base SQLite `sftpgo.db` et les clés SSH sont créées et modifiées sans aucune erreur `Operation not permitted`.
* **Chroot & Utilisateurs Virtuels** : Possibilité de créer des utilisateurs SFTP virtuels cantonnés à un dossier spécifique, sans avoir à créer d'utilisateurs système sur le serveur.

---

## **5. Idempotence, Ports Dynamiques et Synchronisation**

L'orchestrateur [`install.sh`](file:///home/gamo/Documents/ivps/install.sh) est conçu pour être **strictement idempotent** :

* **Arrêt propre avant synchronisation** : Lors d'une ré-exécution, le script suspend temporairement la stack pour éviter de détecter ses propres conteneurs comme des ports occupés.
* **Gestion des collisions de ports** :
  * Si un port par défaut (`8000`, `8080`, `2022`) est libre sur l'hôte, il est automatiquement sélectionné ou rétabli.
  * Si un service tiers externe utilise déjà ce port, le script incrémente dynamiquement vers le prochain port libre et synchronise [`.env`](file:///home/gamo/Documents/ivps/.env).
  * Le port Cockpit natif reste fermement synchronisé sur son port d'écoute réel (**`9090`**).
* **Mot de passe maître unique** : Centralisé dans [`.env`](file:///home/gamo/Documents/ivps/.env), il est initialisé automatiquement au premier déploiement et conservé fidèlement lors des réexécutions.

---

## **6. Synthèse du Workflow Quotidien**

```bash
# 1. Déploiement initial ou mise à jour
./install.sh

# 2. Transférer des fichiers applicatifs (ex: compose.yaml)
# Via Web (https://folder.votre-domaine.com) ou SFTP (sftp://admin@<IP>:2022)

# 3. Démarrer et monitorer vos conteneurs
# Rendez-vous sur https://admin.votre-domaine.com (Cockpit > Podman)

# 4. Router une nouvelle application vers Internet
# Ouvrez https://proxy.votre-domaine.com (Zoraxy > Reverse Proxy > Add Rule)
```
