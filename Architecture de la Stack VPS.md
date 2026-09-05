# **Stack d'Administration VPS : Zoraxy + Cockpit + SFTPGo**

Cette stack hybride (mixant installation native et conteneurs Podman rootless) offre un équilibre parfait entre **sécurité**, **facilité d'utilisation** (interfaces web automatisées) et **puissance d'administration**.

## **1. L'Architecture Globale (Le Flux)**

> 1. **Internet** frappe à la porte de votre serveur sur les ports 80 et 443 (HTTP/HTTPS).  
> 2. **Zoraxy** intercepte tout le trafic, chiffre les connexions (SSL/TLS Let's Encrypt automatique) et applique les règles de sécurité (WAF).  
> 3. En fonction du sous-domaine demandé, Zoraxy redirige automatiquement le trafic vers la bonne cible (**règles pré-provisionnées à l'installation**) :  
   * `admin.votre-domaine.com` (et racine `votre-domaine.com`) ➔ **Cockpit** (console système native avec support WebSocket).  
   * `proxy.votre-domaine.com` ➔ **Zoraxy Web Admin** (console d'administration du proxy).  
   * `folder.votre-domaine.com` (ou `fichiers.*`) ➔ **SFTPGo** (gestionnaire web de fichiers).  
   * `app.votre-domaine.com` ➔ N'importe quel autre conteneur Podman que vous hébergerez plus tard.  
> 4. **SFTP Direct (port 2022)** : Accès direct pour vos clients SFTP (FileZilla, VS Code, Cyberduck).

```text
[ Internet : 80 / 443 ] ──► Zoraxy Reverse Proxy (Podman Rootless)
                               ├── admin.domaine.com (+ racine) ──► Cockpit Console OS (:9090)
                               ├── proxy.domaine.com            ──► Zoraxy Admin Web (:8000)
                               └── folder.domaine.com           ──► SFTPGo Web (:8080)
[ Internet : 2022 ]    ────────────────────────────────────────► SFTPGo SFTP Serveur
```

## **2. Cockpit : La Tour de Contrôle (Installation Native)**

Contrairement aux conteneurs applicatifs, Cockpit s'installe **directement sur le système d'exploitation** de votre VPS (Fedora, RHEL, Debian, Ubuntu). Il s'allume à la demande via un socket Systemd (`cockpit.socket`), consommant littéralement 0 ressource en veille.

* **cockpit-podman :** Le module central de la stack. Téléchargement d'images, gestion du cycle de vie des conteneurs, inspection des métriques CPU/RAM et suivi des journaux en direct.  
* **cockpit-storaged :** Surveillance des disques, partitions, points de montage et santé SMART.  
* **cockpit-pcp (Performance Co-Pilot) :** Historique des métriques système sur plusieurs jours/semaines.  
* **cockpit-packagekit :** Détection et installation des mises à jour système en un clic.  
* **Terminal intégré :** Terminal web complet s'exécutant dans votre contexte utilisateur.  
* **Intégration Reverse Proxy :** `/etc/cockpit/cockpit.conf` est configuré automatiquement par le script d'installation avec les origines WebSocket autorisées (`admin.domaine.com`, `domaine.com`).

## **3. Zoraxy : Le Routeur, Vigile & WAF (Conteneur Podman Rootless)**

Zoraxy est votre **Reverse Proxy & WAF**. C'est le point d'entrée HTTP/HTTPS unique.

* **Pré-configuration automatique (Zero-Conf) :** Dès l'exécution de `./install.sh`, le script [`scripts/03_zoraxy_rules.sh`](file:///home/gamo/Documents/ivps/scripts/03_zoraxy_rules.sh) génère les fichiers de routage JSON dans `conf/proxy/`. Vous n'avez aucune règle de routage manuelle à créer.
* **Page d'accueil & Dashboard :** Le domaine racine (`votre-domaine.com`) propose un portail d'accueil responsive avec boutons d'accès direct vers Cockpit, SFTPGo et Zoraxy.
* **Certificats SSL automatisés :** Gestionnaire ACME Let's Encrypt intégré avec renouvellement automatique et redirection HTTP vers HTTPS.  
* **WAF & Filtrage GeoIP :** Protection contre les attaques web, rate-limiting et restriction par pays.  
* **Isolation Rootless :** Exécution sous un compte utilisateur non privilégié sans droits root sur l'hôte, avec ports 80/443 autorisés via `net.ipv4.ip_unprivileged_port_start=80`.

## **4. SFTPGo : La Gare de Triage des Fichiers (Conteneur Podman Rootless)**

SFTPGo gère le stockage et le transfert de fichiers avec une haute sécurité.

* **Interface Web Moderne :** Explorateur de fichiers accessible dans le navigateur pour téléverser, éditer, renommer et partager des documents.  
* **Protocole SFTP Dédié :** Port 2022 exposé directement sur l'hôte pour vos transferts volumineux et vos outils de développement (VS Code Remote, FileZilla).  
* **Gestion des permissions Podman Rootless :** Volumes montés avec le drapeau `:Z,U` et alignement des droits utilisateur interne (UID `1000:1000`) via `podman unshare`, éliminant tout blocage de permissions SQLite.  
* **Comptes virtuels isolés (Chroot) :** Créez des utilisateurs virtuels restreints à des répertoires dédiés sans créer de comptes Linux sur l'hôte.

## **5. Synthèse du Déploiement et du Workflow Quotidien**

### **Déploiement Initial (1 commande)**
```bash
git clone https://github.com/guomangu/iVPS.git && cd iVPS && ./install.sh
```

### **Workflow Quotidien**
1. **Dépôt des fichiers** : Vous transférez vos applications ou fichiers `compose.yaml` via SFTP (`port 2022`) ou l'interface web SFTPGo (`https://folder.domaine.com`).  
2. **Gestion & Suivi** : Vous supervisez et démarrez vos conteneurs depuis **Cockpit** (`https://admin.domaine.com`).  
3. **Routage de nouveaux services** : Vous ouvrez **Zoraxy** (`https://proxy.domaine.com`) pour associer en quelques clics un sous-domaine à votre nouveau conteneur.  
4. **Maintenance en continu** : Les conteneurs redémarrent automatiquement au redémarrage du VPS grâce à `loginctl enable-linger` et l'unité `systemd --user ivps-stack.service`.
