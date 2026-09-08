# Conteneurs de la Stack IVPS

La stack repose sur des conteneurs exécutés en mode **rootless Podman** avec le réseau hôte (`--network host`), assurant sécurité, isolation et accès direct sans latence ni translation NAT.

## Services Inclus

| Service | Image | Rôle | Mode Réseau | Ports Directs Hôte |
|---|---|---|---|---|
| **Zoraxy** | `zoraxydocker/zoraxy:latest` | Reverse Proxy, SSL automatique, WAF | Host (`--network host`) | 80, 443, 8000 |
| **pgAdmin** | `dpage/pgadmin4:latest` | Interface Web administrative pour PostgreSQL | Host (`--network host`) | 5050 |

## Cycle de Vie

Les conteneurs sont définis dans [`compose.yaml`](file:///home/gamo/Documents/ivps/compose.yaml) et orchestrés par :
- Le service `systemd --user` : `ivps-stack.service`
- L'interface d'administration Cockpit (module `cockpit-podman`)

Pour lancer manuellement la stack :
```bash
podman compose up -d
```
