# Conteneurs de la Stack IVPS

La stack repose sur des conteneurs Podman avec le réseau hôte, assurant isolation et accès direct sans latence NAT. **Zoraxy et pgAdmin sont rootless** ; **wg-easy est rootful** car il doit créer `wg0` dans le namespace réseau de l'hôte pour être joignable par Zoraxy.

## Services Inclus

| Service | Image | Rôle | Mode Podman | Ports Directs Hôte |
|---|---|---|---|---|
| **Zoraxy** | `zoraxydocker/zoraxy:latest` | Reverse Proxy, SSL automatique, WAF | Rootless, `--network host` | 80, 443, 8000 |
| **pgAdmin** | `dpage/pgadmin4:latest` | Interface Web PostgreSQL | Rootless, `--network host` | 5050 |
| **wg-easy** | `ghcr.io/wg-easy/wg-easy:15` | VPN WireGuard + UI | **Rootful**, `--network host` | UDP 51820, `127.0.0.1:9999` |

## Cycle de Vie

- **Zoraxy + pgAdmin** : définis dans [`compose.yaml`](../compose.yaml), orchestrés par le service `systemd --user` `ivps-stack.service` et visibles dans Cockpit (`cockpit-podman`).
- **wg-easy** : unité Quadlet rootful générée dans `/etc/containers/systemd/ivps-wireguard.container` par [`scripts/02_install_wireguard.sh`](../scripts/02_install_wireguard.sh), puis exposée par `ivps-wireguard.service`.

```bash
# Stack rootless
podman compose up -d

# Service WireGuard rootful
systemctl status ivps-wireguard.service
sudo podman exec ivps-wireguard wg show
```

Voir [`wireguard/README.md`](wireguard/README.md) pour les détails et le dépannage du VPN.
