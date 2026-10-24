# WireGuard / wg-easy

Cette brique fournit un VPN WireGuard avec interface web d'administration, intégré à iVPS.

## Fichiers

| Fichier | Rôle |
|---|---|
| `wg-easy.container.in` | Modèle Quadlet rendu par `scripts/02_install_wireguard.sh` |
| `../../config/sysctl/99-ivps-wireguard.conf` | Sysctls requis sur l'hôte (`ip_forward`, `src_valid_mark`, IPv6) |
| `../../config/modules-load/ivps-wireguard.conf` | Modules noyau chargés au boot (`wireguard`, `nft_masq`) |
| `../../data/wireguard/` | Données persistantes (clés, clients, `wg-easy.db`, `wg-easy.env`) |

## Mode rootful obligatoire

Le conteneur tourne avec **Podman rootful** et `Network=host`. C'est la seule façon de créer `wg0` dans le namespace réseau de l'hôte afin que :

- Zoraxy puisse joindre `10.8.0.x` et proxyfier un service du tunnel ;
- les clients WireGuard accèdent à Internet via le NAT de l'hôte.

Zoraxy et pgAdmin restent rootless.

## UI privée

Par défaut, l'UI écoute sur `127.0.0.1:9999` (`WG_UI_BIND=127.0.0.1`). Elle n'est accessible qu'à travers Zoraxy :

- règle générée : `vpn.<DOMAIN_NAME>` ➔ `127.0.0.1:9999` ;
- `WG_INSECURE=false` : cookies sécurisés derrière le TLS de Zoraxy.

Pour un accès direct de secours, mettez `WG_UI_BIND=0.0.0.0` ; `scripts/03_configure.sh` ouvrira alors le port TCP dans le pare-feu.

## Commandes

```bash
systemctl status ivps-wireguard.service
journalctl -u ivps-wireguard.service -f
sudo podman exec ivps-wireguard wg show
ip a show wg0
ip route get 10.8.0.2
```

## Dépannage

| Symptôme | Vérification |
|---|---|
| Service inactif | `journalctl -u ivps-wireguard.service -n 80` |
| UI 502 via Zoraxy | `curl -I http://127.0.0.1:9999/` et vérifier `WG_UI_BIND` |
| Pas d'accès Internet des clients | `sudo iptables -t nat -S POSTROUTING \| grep 10.8.0.0` ; vérifier `WG_WAN_DEVICE` |
| `wg0` absent de l'hôte | vérifier que le service est rootful et que `Network=host` est bien appliqué |
| Conflit après migration | l'ancien `wg-easy.service` doit être arrêté/retiré (fait automatiquement) |

La correction du NAT est automatisée par `scripts/05_init_wireguard.sh` : elle détecte l'interface de la route par défaut et met à jour la colonne `device` de `interfaces_table`.
