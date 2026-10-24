# **Stack d'Administration VPS : Zoraxy + Cockpit + pgAdmin + WireGuard**

Cette stack hybride (services natifs, conteneurs Podman rootless et une exception rootful dédiée au VPN) offre un équilibre entre **sécurité**, **facilité d'administration** et **accès distant chiffré**. Zoraxy et pgAdmin restent rootless ; wg-easy est rootful car il doit créer `wg0` dans le namespace réseau de l'hôte.

---

## **1. L'Architecture Globale (Le Flux)**

```text
                                 ┌───────────────────────────────────────────────────────────┐
                                 │                    INTERNET                               │
                                 └───────────┬───────────────────────────────┬───────────────┘
                                             │                               │
                              TCP 80 / 443   │                               │   UDP 51820
                                             ▼                               ▼
                        ┌───────────────────────────────────┐   ┌──────────────────────────────┐
                        │       ZORAXY (Reverse Proxy)      │   │   wg-easy (Podman ROOTFUL)   │
                        │  Podman rootless --network host   │   │   --network host, Quadlet    │
                        │  Ports : 80, 443, admin 8000      │   │   wg0 : 10.8.0.0/24          │
                        └───┬───────────┬───────────┬───────┘   └──────────────┬───────────────┘
                            │           │           │                          │
      https://admin.*       │           │           │ https://vpn.*           │
                            ▼           │           ▼                          ▼
                 ┌─────────────────┐    │    ┌─────────────┐        ┌─────────────────────┐
                 │ Cockpit (natif) │    │    │ wg-easy UI  │        │ Clients du tunnel   │
                 │ Port 9090       │    │    │ 127.0.0.1   │        │ 10.8.0.2, 10.8.0.3… │
                 └─────────────────┘    │    │  :9999      │        └─────────────────────┘
                                        ▼    └─────────────┘
                              https://proxy.*  ┌─────────────┐
                                               │ Zoraxy Admin│
                                               │ Port 8000   │
                                               └─────────────┘
                              https://db.*     ┌─────────────┐
                                               │  pgAdmin 4  │
                                               │ Port 5050   │
                                               └─────────────┘
```

### Flux d'Exécution

1. **Point d'entrée unique web** : Internet contacte les ports **80/443**. Zoraxy termine le TLS, applique son WAF et route par sous-domaine.
2. **Routage Zero-Conf** (communication loopback hôte) :
   * `admin.domaine.com` ➔ **Cockpit** (`http://127.0.0.1:9090`, WebSockets activés).
   * `proxy.domaine.com` ➔ **Zoraxy Web Admin** (`http://127.0.0.1:8000`).
   * `db.domaine.com` ➔ **pgAdmin 4** (`http://127.0.0.1:5050`).
   * `vpn.domaine.com` ➔ **wg-easy UI** (`http://127.0.0.1:9999`).
3. **Point d'entrée VPN** : les clients WireGuard joignent **UDP 51820**. wg-easy crée `wg0` et le sous-réseau `10.8.0.0/24` **directement sur l'hôte**.
4. **Accès aux machines du tunnel** : puisque `wg0` est visible sur l'hôte, Zoraxy peut proxyfier un service interne, par exemple `okay.domaine.com` ➔ `10.8.0.2:8096`.
5. **Authentification** : aucun portail public sur le domaine racine. Chaque interface demande les identifiants définis dans `.env` (le VPN conserve toutefois les identifiants de sa base lors d'une migration).

---

## **2. Cockpit : La Tour de Contrôle (Installation Native)**

* **Consommation nulle au repos** : activé à la demande par `cockpit.socket`.
* **Synchronisation avec l'utilisateur hôte** : `ADMIN_USER` est rattaché à `wheel`/`sudo` et son mot de passe est aligné sur `ADMIN_PASSWORD`.
* **cockpit-podman** : gestion visuelle des conteneurs, images, réseaux et volumes Podman.

---

## **3. Zoraxy : Routeur, Vigile & WAF (Podman Rootless, Mode Host)**

* **Routage Zero-Conf** : `scripts/03_zoraxy_rules.sh` écrit les règles JSON dans `conf/proxy/`.
* **Séparation stockage** : `conf/` contient les règles et certificats ; `sys.db` contient les sessions et métriques.
* **Auto-guérison** : `scripts/05_init_auth.sh` teste les identifiants et réinitialise `sys.db` en cas de divergence, sans toucher aux règles de proxy.
* **ACME / SSL** : certificats Let's Encrypt générés et renouvelés automatiquement, redirection HTTPS forcée.

---

## **4. pgAdmin : Administration PostgreSQL (Podman Rootless, Mode Host)**

* **SubUIDs** : l'UID interne `5050:5050` est mappé via `podman unshare chown` et le volume `:Z,U`.
* **Identifiants** : `PGADMIN_DEFAULT_EMAIL` et `PGADMIN_DEFAULT_PASSWORD` dérivent de `ADMIN_USER` / `ADMIN_PASSWORD`.
* **Accès** : `https://db.domaine.com` ou `127.0.0.1:5050`.

---

## **5. WireGuard / wg-easy : VPN et Accès aux Réseaux Distants (Podman ROOTFUL)**

### Pourquoi rootful ?

WireGuard doit créer l'interface `wg0`, modifier les routes et le NAT de l'hôte. Un conteneur rootless ne dispose pas de `CAP_NET_ADMIN` dans le namespace réseau initial ; `wg0` resterait invisible pour Zoraxy. **Seul wg-easy est rootful**, via une unité Quadlet système (`ivps-wireguard.service`). Zoraxy et pgAdmin restent rootless.

### Fonctionnement

* **Données** : `data/wireguard/` (clés serveur, base SQLite, clients), monté sur `/etc/wireguard`.
* **Réseau** : `Network=host`, `wg0` et `10.8.0.0/24` visibles par l'hôte.
* **UI** : écoute par défaut sur `127.0.0.1:9999`, exposée uniquement par Zoraxy (`https://vpn.domaine.com`).
* **NAT sortant** : `scripts/05_init_wireguard.sh` détecte l'interface de la route par défaut et corrige la colonne `device` de wg-easy (`ens3`, `eth0`, …). Les clients ont ainsi accès à Internet.
* **Sysctls** : `ip_forward`, `src_valid_mark` et forwarding IPv6 sont appliqués à l'hôte par `/etc/sysctl.d/99-ivps-wireguard.conf` (impossible avec `--sysctl` en mode host).
* **Migration** : à la première installation, les données de `reversevpn/` sont importées automatiquement.

### Exposer un service du tunnel via Zoraxy

| Champ Zoraxy | Valeur |
|---|---|
| Type | HTTP |
| Root domain | `okay.domaine.com` |
| Upstream | `10.8.0.2:8096` |

Zoraxy termine le TLS et relaie vers la machine du tunnel.

---

## **6. Tableau Récapitulatif de la Stack**

| Service | Mode d'installation | Rôle | URL d'accès | Port direct hôte |
| :--- | :--- | :--- | :--- | :--- |
| **Zoraxy** | Podman rootless (`--network host`) | Reverse Proxy & WAF | `https://proxy.domaine.com` | `8000` |
| **Cockpit** | Natif OS (systemd socket) | Administration Système | `https://admin.domaine.com` | `9090` |
| **pgAdmin 4** | Podman rootless (`--network host`) | UI PostgreSQL | `https://db.domaine.com` | `5050` |
| **wg-easy** | Podman **rootful** Quadlet (`--network host`) | VPN WireGuard & UI | `https://vpn.domaine.com` | `127.0.0.1:9999` |
| **WireGuard** | Interface hôte `wg0` | Tunnel clients | *Non applicable* | `UDP 51820` |

---

## **7. Scénario d'Utilisation Réel**

```bash
# 1. Inspecter les métriques système
#    https://admin.domaine.com

# 2. Gérer PostgreSQL
#    https://db.domaine.com

# 3. Gérer certificats, WAF et routage
#    https://proxy.domaine.com

# 4. Créer un client VPN et télécharger sa configuration
#    https://vpn.domaine.com

# 5. Exposer un service du tunnel (ex. Jellyfin sur 10.8.0.2:8096)
#    Zoraxy ➔ Proxy ➔ okay.domaine.com ➔ 10.8.0.2:8096

# 6. Reconfigurer
nano .env
./install.sh
```
