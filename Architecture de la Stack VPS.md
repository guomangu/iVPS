# **Stack d'Administration VPS : Zoraxy + Cockpit + pgAdmin**

Cette stack hybride (mixant installation native et conteneurs Podman rootless en mode réseau hôte `--network host`) offre un équilibre parfait entre **sécurité**, **facilité d'utilisation** (interfaces web automatisées) et **puissance d'administration**.

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
                                 │         Conteneur Podman Rootless (--network host)        │
                                 │        Ports d'écoute hôte : 80, 443, Admin : 8000        │
                                 └──────────────┬──────────────────┬──────────────────┬──────┘
                                                │                  │                  │
               https://admin.votre-domaine.com  │                  │                  │ https://db.votre-domaine.com
                                                ▼                  │                  ▼
                                 ┌─────────────────────┐           │           ┌─────────────────────┐
                                 │  Cockpit Console OS │           │           │     pgAdmin 4       │
                                 │   (Service Natif)   │           │           │  (--network host)   │
                                 │     (Port 9090)     │           │           │     (Port 5050)     │
                                 └─────────────────────┘           │           └─────────────────────┘
                                                                   ▼
                                                        https://proxy.votre-domaine.com
                                                        ┌─────────────────────┐
                                                        │  Zoraxy Web Admin   │
                                                        │     (Port 8000)     │
                                                        └─────────────────────┘
```

### Flux d'Exécution
1. **Point d'entrée unique** : Internet contacte votre serveur exclusivement sur les ports **80** (HTTP) et **443** (HTTPS).
2. **Filtrage et Chiffrement** : **Zoraxy** intercepte toutes les requêtes, gère le chiffrement SSL/TLS (Let's Encrypt automatique) et bloque les attaques via son WAF intégré.
3. **Routage Automatique par Sous-Domaine (Zero-Conf)** : Zoraxy dispatche instantanément vers le service approprié grâce aux règles générées dès l'installation (communication directe sur l'interface loopback hôte) :
   * `admin.votre-domaine.com` ➔ **Cockpit** (`http://127.0.0.1:9090` avec support WebSockets).
   * `proxy.votre-domaine.com` ➔ **Zoraxy Web Admin** (`http://127.0.0.1:8000`).
   * `db.votre-domaine.com` ➔ **pgAdmin 4** (`http://127.0.0.1:5050`).
   * `*.votre-domaine.com` ➔ N'importe quelle future application conteneurisée.
4. **Authentification Unifiée dès la Première Connexion** :
   * Aucun portail public non filtré sur le domaine racine.
   * L'accès à chaque interface sollicite immédiatement les identifiants centraux définis dans le `.env` (`ADMIN_USER` / `ADMIN_PASSWORD`).

---

## **2. Cockpit : La Tour de Contrôle (Installation Native)**

Contrairement aux applications conteneurisées, Cockpit s'installe **directement sur le système d'exploitation** de votre VPS (Fedora, RHEL, Debian, Ubuntu).

### Points forts techniques
* **Consommation Zéro au repos** : Activé à la demande par socket Systemd (`cockpit.socket`), il ne consomme aucune ressource CPU/RAM en veille.
* **Synchronisation avec Utilisateur Hôte** : Le script détecte et synchronise l'utilisateur spécifié dans `ADMIN_USER` (utilisateur natif existant du VPS ou nouveau compte), lui accorde les privilèges d'administration (`wheel`/`sudo`) et synchronise le mot de passe maître.
* **cockpit-podman** : Gestion visuelle complète des conteneurs, images, réseaux et volumes Podman rootless.

---

## **3. Zoraxy : Le Routeur, Vigile & WAF (Conteneur Podman Rootless - Mode Host)**

Zoraxy est votre **Reverse Proxy & WAF**. C'est le bouclier réseau de votre infrastructure. Exécuté avec `--network host`, il communique sans latence ni surcharge de translation d'adresse (NAT) avec les services locaux.

### Fonctionnalités Clés & Gestion de l'Authentification
* **Routage Zero-Conf** : Le script `scripts/03_zoraxy_rules.sh` écrit directement les fichiers de règles au format JSON dans `conf/proxy/`. L'accès est fonctionnel dès la première minute.
* **Séparation Stockage (`conf/` vs `sys.db`)** :
  - `conf/` : Héberge la configuration réseau, les certificats SSL et les règles de proxy sous forme de fichiers JSON persistants.
  - `sys.db` : Base embarquée BoltDB contenant les sessions d'administration et les métriques de trafic.
* **Auto-Guérison et Synchronisation Continue** :
  - Lors de chaque exécution de `./install.sh`, le script teste activement l'authentification avec les identifiants déclarés dans `.env`.
* **Gestionnaire ACME / SSL** : Certificats Let's Encrypt générés et renouvelés automatiquement avec redirection HTTPS forcée.

---

## **4. pgAdmin : L'Administration PostgreSQL Web (Conteneur Podman Rootless - Mode Host)**

pgAdmin 4 permet d'administrer graphiquement vos bases de données PostgreSQL via une interface web, branché directement sur la pile réseau de l'hôte (`--network host`).

### Gestion avancée des permissions sous Podman Rootless
* **Le défi des subUIDs** : Dans un conteneur rootless, pgAdmin s'exécute avec son propre UID interne non privilégié (`UID 5050:GID 5050`), qui correspond sur l'hôte à un sous-identifiant dédié.
* **La solution de la Stack** : Utilisation conjointe du flag de volume `:Z,U` et de `podman unshare chown -R 5050:5050 data/pgadmin` pour garantir des droits d'écriture sans restriction au volume pgAdmin.
* **Synchronisation des Comptes** : Le script configure `PGADMIN_DEFAULT_EMAIL` et `PGADMIN_DEFAULT_PASSWORD` depuis les variables `.env`.

---

## **5. Tableau Récapitulatif de la Stack**

| Service | Mode d'installation | Rôle | URL d'accès | Port direct hôte | Identifiant maître |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Zoraxy** | Conteneur Podman rootless (`--network host`) | Reverse Proxy & WAF | `https://proxy.votre-domaine.com` | `8000` | `<ADMIN_USER>` / `<MDP_ENV>` |
| **Cockpit** | Natif OS (systemd socket) | Administration Système | `https://admin.votre-domaine.com` | `9090` | `<ADMIN_USER>` / `<MDP_ENV>` |
| **pgAdmin 4** | Conteneur Podman rootless (`--network host`) | UI de base de données | `https://db.votre-domaine.com` | `5050` | `<ADMIN_USER>@<DOMAIN>` / `<MDP_ENV>` |

---

## **6. Scénario d'Utilisation Réel**

```bash
# 1. Se connecter à la console Cockpit pour inspecter les métriques
# Rendez-vous sur : https://admin.votre-domaine.com

# 2. Gérer vos bases de données PostgreSQL
# Rendez-vous sur : https://db.votre-domaine.com

# 3. Gérer les certificats SSL Let's Encrypt et le WAF
# Rendez-vous sur : https://proxy.votre-domaine.com

# 4. Mettre à jour les identifiants ou reconfigurer
nano .env
./install.sh
```
