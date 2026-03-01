# Media Stack

GitOps-managed media automation stack running in the `media` namespace on k3s.

## Architecture

```
Jellyseerr (search/request UI)
       │
       ▼
Sonarr (TV) ◄──── Prowlarr (indexer manager) ────► FlareSolverr (Cloudflare bypass)
Radarr (Movies) ◄─┘            │
       │                       │
       ▼                       ▼
qBittorrent ◄──── Gluetun (VPN sidecar, PIA OpenVPN)
       │
       ▼
NFS: /media/downloads
       │
  (import/hardlink)
       │
       ▼
/media/movies  ──► Plex / Jellyfin
/media/tv      ──►
```

## Components

| App | Internal URL | Web UI | Purpose |
|-----|-------------|--------|---------|
| Prowlarr | `prowlarr.media.svc:9696` | `prowlarr.json.lab` | Indexer management, syncs to Sonarr/Radarr |
| Sonarr | `sonarr.media.svc:8989` | `sonarr.json.lab` | TV show automation |
| Radarr | `radarr.media.svc:7878` | `radarr.json.lab` | Movie automation |
| qBittorrent | `qbittorrent.media.svc:8080` | `qbittorrent.json.lab` | Download client (behind VPN) |
| Jellyfin | `jellyfin.media.svc:8096` | `jellyfin.json.lab` | Media streaming |
| Plex | `plex.media.svc:32400` | `plex.json.lab` | Media streaming |
| Jellyseerr | `jellyseerr.media.svc:5055` | `jellyseerr.json.lab` | User-facing search/request UI |
| FlareSolverr | `flaresolverr.media.svc:8191` | — | Cloudflare bypass proxy for Prowlarr |

## Storage

- **NFS mount** (`media-pvc`): `/media` in all pods → NFS server `192.168.124.10:/mnt/storage/media`
  - `/media/movies` — Radarr root folder, Plex/Jellyfin movies library
  - `/media/tv` — Sonarr root folder, Plex/Jellyfin TV library
  - `/media/downloads` — qBittorrent save path
- **Config PVCs** (local-path): each app has a `<app>-config` PVC for settings persistence

## Secrets

Managed via `.envrc` + `scripts/apply-secrets.sh`:

| Secret | Namespace | Used by |
|--------|-----------|---------|
| `vpn-credentials` | media | qBittorrent (Gluetun sidecar) |
| `plex-claim` | media | Plex (initial claim) |
| `exportarr-api-keys` | media | Exportarr sidecars (Prometheus metrics) |

## Monitoring

Exportarr sidecars run alongside Sonarr, Radarr, and Prowlarr. A standalone exporter runs for qBittorrent.

| Exporter | Metrics port | Prometheus job |
|----------|-------------|----------------|
| Sonarr | 9707 | `sonarr` |
| Radarr | 9708 | `radarr` |
| Prowlarr | 9709 | `prowlarr` |
| qBittorrent | 8000 | `qbittorrent` |

## Inter-app Wiring

These connections are configured in each app's web UI (not in manifests):

1. **Prowlarr → Sonarr/Radarr**: Settings → Apps, use internal service URLs + API keys
2. **Sonarr/Radarr → qBittorrent**: Settings → Download Clients, host `localhost` won't work — use `qbittorrent.media.svc.cluster.local:8080`
3. **Sonarr/Radarr → Plex**: Settings → Connect → Plex Media Server, host `plex.media.svc.cluster.local:32400`
4. **Sonarr/Radarr → Jellyfin**: Settings → Connect → Emby/Jellyfin, host `jellyfin.media.svc.cluster.local:8096` + API key
5. **Prowlarr → FlareSolverr**: Settings → Indexers → add tag, Indexer Proxies → FlareSolverr at `flaresolverr.media.svc.cluster.local:8191`

## Troubleshooting

### Downloads not appearing in Plex/Jellyfin
- Verify libraries are configured: Plex/Jellyfin must have libraries pointed at `/media/movies` and `/media/tv`
- Check Sonarr/Radarr → Settings → Connect — Plex/Jellyfin notifications trigger library scans on import
- Manual scan: trigger from Plex Settings → Libraries or Jellyfin Dashboard → Libraries

### Sonarr/Radarr can't connect to qBittorrent
- Verify qBittorrent is running: `kubectl -n media get pods -l app=qbittorrent`
- Check the password hasn't changed — qBittorrent generates a temp password on first boot (check logs)
- If password is lost, scale down, remove `Password_PBKDF2` line from config, scale back up — it defaults to `admin/adminadmin`
- Use host `qbittorrent.media.svc.cluster.local` port `8080` in Sonarr/Radarr

### qBittorrent password reset
```bash
kubectl -n media scale deployment qbittorrent --replicas=0
# Run a temp pod to edit the config on the PVC:
kubectl -n media run qbt-fix --rm -it --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"fix","image":"busybox","command":["sh","-c","grep -v Password_PBKDF2 /config/qBittorrent/qBittorrent.conf > /tmp/qbt.conf && cp /tmp/qbt.conf /config/qBittorrent/qBittorrent.conf && echo done"],"volumeMounts":[{"name":"config","mountPath":"/config"}]}],"volumes":[{"name":"config","persistentVolumeClaim":{"claimName":"qbittorrent-config"}}]}}' \
  --image=busybox
kubectl -n media scale deployment qbittorrent --replicas=1
# Default creds: admin / adminadmin
```

### VPN not working
- Check Gluetun logs: `kubectl -n media logs deploy/qbittorrent -c gluetun`
- Verify VPN IP: `kubectl -n media exec deploy/qbittorrent -c gluetun -- wget -qO- ifconfig.me`
- If AUTH_FAILED: re-run `source .envrc && ./scripts/apply-secrets.sh` then restart the pod

### NFS permission errors
- All linuxserver containers run as UID 1000 — ensure NFS dirs are owned correctly:
  ```bash
  ssh jasonwc@192.168.124.10 'sudo chown -R 1000:1000 /mnt/storage/media'
  ```

### Prowlarr indexer failures (Cloudflare)
- Add FlareSolverr as an Indexer Proxy in Prowlarr: Settings → Indexer Proxies
- Create a tag (e.g., `flaresolverr`) and assign it to both the proxy and the affected indexers

### Pod stuck / not starting
- Check events: `kubectl -n media describe pod <pod-name>`
- Check logs: `kubectl -n media logs deploy/<app> -c <container>`
- Restart: `kubectl -n media rollout restart deployment <app>`
