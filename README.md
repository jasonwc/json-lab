# json-lab

GitOps-managed k3s homelab running on GMKTek Mini PCs (Ryzen 5 3500) with NixOS.

## Cluster Overview

| Node  | Role                  | IP            | Notes                      |
|-------|-----------------------|---------------|----------------------------|
| json-lab-1 | Control plane + worker| 192.168.124.10  | 8TB external drive, NFS server |
| json-lab-2 | Worker                | 192.168.124.11  |                            |
| json-lab-3 | Worker                | 192.168.124.12  | Pending hardware           |

## Stack

- **OS**: NixOS (flake-based)
- **Orchestration**: k3s
- **GitOps**: ArgoCD (app-of-apps pattern)
- **Load Balancer**: MetalLB (L2 mode, IP pool 192.168.124.200-210)
- **Ingress**: ingress-nginx (gets a MetalLB IP)
- **Monitoring**: Prometheus + Grafana + node-exporter + kube-state-metrics + exportarr sidecars
- **Storage**: NFS from json-lab-1's 8TB drive + local-path for app configs
- **Router**: Firewalla Gold Pro (DHCP, DNS, firewall, WireGuard VPN)

## Services

### Media Stack (`media` namespace)

| Service | URL | Purpose |
|---------|-----|---------|
| Jellyfin | jellyfin.json.lab | Media streaming (open source) |
| Plex | plex.json.lab | Media streaming |
| Sonarr | sonarr.json.lab | TV show management |
| Radarr | radarr.json.lab | Movie management |
| Prowlarr | prowlarr.json.lab | Indexer management |
| qBittorrent | qbittorrent.json.lab | Torrent client (VPN via Gluetun) |
| Jellyseerr | jellyseerr.json.lab | Media request UI |
| FlareSolverr | (internal only) | Cloudflare bypass for Prowlarr |

### Homelab Services (`homelab` namespace)

| Service | URL | Purpose |
|---------|-----|---------|
| Homepage | home.json.lab | Dashboard with links to all services |
| Uptime Kuma | status.json.lab | Service monitoring & status page |
| Home Assistant | ha.json.lab | Home automation |

### Infrastructure

| Service | URL | Purpose |
|---------|-----|---------|
| ArgoCD | argocd.json.lab | GitOps deployment management |
| Grafana | grafana.json.lab | Dashboards & visualization |
| Prometheus | prometheus.json.lab | Metrics collection |

## Network Architecture

```
Internet
  │
  ▼
Firewalla Gold Pro (router/firewall/DNS/WireGuard)
  │  DNS: *.json.lab → 192.168.124.200 (MetalLB ingress IP)
  │  WireGuard VPN server for remote access
  │
  ├─ 192.168.124.10  json-lab-1 (control plane + worker + NFS)
  ├─ 192.168.124.11  json-lab-2 (worker)
  └─ 192.168.124.12  json-lab-3 (worker)

Ingress path:
  Client → Firewalla DNS → 192.168.124.200 (MetalLB VIP)
    → ingress-nginx (Host header routing)
      → ClusterIP Service → Pod

Remote access:
  Phone/Laptop → WireGuard → Firewalla → LAN → same path as above
```

### DNS Setup (Firewalla)

In the Firewalla app: **Services → Custom DNS Rules**, add a wildcard entry:

| Domain | IP |
|--------|-----|
| `*.json.lab` | `192.168.124.200` |

**Note:** Disable DNS-over-HTTPS (DoH) for the LAN network, as DoH bypasses local DNS entries.

### MetalLB IP Pool

MetalLB runs in L2 mode and assigns IPs from `192.168.124.200-192.168.124.210`. Reserve this range in your Firewalla's DHCP settings to avoid conflicts.

## Repo Structure

```
json-lab/
├── nixos/                     # NixOS flake configs for all 3 nodes
├── cluster/
│   ├── bootstrap/argocd/      # ArgoCD installation + patches
│   ├── apps/                  # ArgoCD Application CRDs (app-of-apps)
│   │   ├── argocd.yaml        # Self-managing ArgoCD
│   │   ├── infrastructure.yaml # MetalLB, ingress, monitoring, NFS
│   │   ├── media-stack.yaml   # All media apps
│   │   └── homelab.yaml       # Homepage, Uptime Kuma, Home Assistant
│   ├── infrastructure/
│   │   ├── metallb/           # L2 load balancer
│   │   ├── ingress-nginx/     # Ingress controller
│   │   ├── nfs-storage/       # NFS PV/PVC for shared media
│   │   └── monitoring/        # Prometheus, Grafana, dashboards
│   ├── media-stack/           # Media apps (each: deployment, service, ingress)
│   │   ├── jellyfin/
│   │   ├── plex/
│   │   ├── sonarr/            # + exportarr sidecar
│   │   ├── radarr/            # + exportarr sidecar
│   │   ├── prowlarr/          # + exportarr sidecar
│   │   ├── qbittorrent/       # + gluetun VPN + port-updater sidecar
│   │   ├── jellyseerr/
│   │   └── flaresolverr/
│   └── homelab/               # General homelab services
│       ├── homepage/
│       ├── uptime-kuma/
│       └── home-assistant/
├── firewalla/                 # Firewalla DNS/DHCP docs
├── scripts/
│   └── apply-secrets.sh       # Creates k8s secrets from .envrc
└── .envrc                     # Secret values (DO NOT COMMIT)
```

## Getting Started

### 1. Deploy NixOS to nodes

```bash
nix flake check ./nixos
sudo nixos-rebuild switch --flake ./nixos#json-lab-1
```

### 2. Bootstrap the cluster

After k3s is running on all nodes:

```bash
# Copy kubeconfig from json-lab-1
scp jasonwc@192.168.124.10:/etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i 's/127.0.0.1/192.168.124.10/' ~/.kube/config

# Bootstrap infrastructure in order
kubectl apply -k cluster/infrastructure/metallb/
kubectl apply -k cluster/infrastructure/ingress-nginx/
kubectl apply -f cluster/infrastructure/nfs-storage/
kubectl apply -k cluster/bootstrap/argocd/
```

### 3. Create secrets (not stored in repo)

Edit `.envrc` with your credentials, then:

```bash
source .envrc && ./scripts/apply-secrets.sh
```

Required secrets (see `.envrc` for all variables):
- VPN credentials (PIA, for Gluetun/qBittorrent)
- Plex claim token
- Exportarr API keys (Sonarr, Radarr, Prowlarr)
- qBittorrent WebUI credentials
- Grafana admin password

### 4. Deploy apps via ArgoCD

```bash
kubectl apply -f cluster/apps/

# Access ArgoCD at argocd.json.lab
# Default user: admin
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## Storage Layout

```
8TB External Drive (json-lab-1:/mnt/storage)
├── media/
│   ├── movies/        ← Radarr imports, Plex/Jellyfin reads
│   ├── tv/            ← Sonarr imports, Plex/Jellyfin reads
│   └── downloads/     ← qBittorrent incomplete + complete
└── (shared via NFS to all nodes as media-pvc)

Per-app config PVCs (local-path provisioner, 1Gi each):
  jellyfin-config, plex-config, sonarr-config, radarr-config,
  prowlarr-config, qbittorrent-config, etc.
```

## Monitoring

### Prometheus scrape targets

| Target | Metrics |
|--------|---------|
| node-exporter | CPU, memory, disk, network per node |
| kube-state-metrics | Pod/deployment/node status |
| kubelet + cAdvisor | Container resource usage |
| k8s API server | API request metrics |
| ingress-nginx | Request rates, latencies, error rates |
| Sonarr exportarr | Series, episodes, queue |
| Radarr exportarr | Movies, queue |
| Prowlarr exportarr | Indexer stats, queries |
| qBittorrent exporter | Torrents, speeds, connection status |

### Grafana dashboards (provisioned automatically)

- **Cluster Overview** — Node CPU/memory/disk, pod counts, container resources
- **Media Stack** — Sonarr/Radarr/Prowlarr/qBittorrent stats

## qBittorrent + VPN

qBittorrent runs with a Gluetun sidecar (PIA OpenVPN) and a port-updater sidecar:

1. **Gluetun** connects to PIA, enables kill switch, gets a forwarded port
2. **port-updater** reads the forwarded port from Gluetun and updates qBittorrent's listen port via API
3. **qBittorrent** downloads through the VPN tunnel with proper port forwarding for peers

Verify VPN is working:
```bash
kubectl exec -n media deploy/qbittorrent -c gluetun -- curl -s ifconfig.me
```

## Verification Checklist

1. `nix flake check ./nixos` — NixOS configs valid
2. ArgoCD UI (`argocd.json.lab`) shows all apps synced and healthy
3. `kubectl exec -n media deploy/qbittorrent -c gluetun -- curl -s ifconfig.me` — shows VPN IP
4. Add a show in Sonarr → downloads in qBittorrent → appears in Jellyfin/Plex
5. `prometheus.json.lab/targets` — all scrape targets UP
6. `grafana.json.lab` — dashboards show live cluster and media data
7. `status.json.lab` — Uptime Kuma monitors all green
8. `home.json.lab` — Homepage shows all services

## Future Improvements

- [ ] SOPS or Sealed Secrets for encrypted secrets in-repo
- [ ] Automated backups for app configs and PVCs
- [ ] Cloudflare Tunnel or Tailscale for public access
- [ ] Bazarr for automatic subtitle downloads
- [ ] cert-manager for TLS on ingress
