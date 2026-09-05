# Conteneurs de la Stack IVPS

La stack repose sur des conteneurs exécutés en mode **rootless Podman**, assurant sécurité et isolation.

## Services Inclus

| Service | Image | Rôle | Ports Exposés |
|---|---|---|---|
| **Zoraxy** | `zoraxydocker/zoraxy:latest` | Reverse Proxy, SSL automatique, WAF | 80, 443, 8000 |
| **SFTPGo** | `drakkan/sftpgo:latest` | Gestionnaire de fichiers Web et serveur SFTP | 8080, 2022 |

## Cycle de Vie

Les conteneurs sont définis dans [`compose.yaml`](file:///home/gamo/Documents/ivps/compose.yaml) et orchestrés par :
- Le service `systemd --user` : `ivps-stack.service`
- L'interface d'administration Cockpit (module `cockpit-podman`)

Pour lancer manuellement la stack :
```bash
podman compose up -d
```
