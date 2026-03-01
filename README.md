# json-lab

GitOps-managed k3s homelab running on 3 GMKTek Mini PCs (Ryzen 5 3500) with NixOS.

## Cluster Overview

| Node  | Role                  | IP            | Notes                      |
|-------|-----------------------|---------------|----------------------------|
| json-lab-1 | Control plane + worker| 192.168.124.10  | 8TB external drive, NFS server |
| json-lab-2 | Worker                | 192.168.124.11  |                            |
| json-lab-3 | Worker                | 192.168.124.12  |                            |

## Stack

- **OS**: NixOS (flake-based)
- **Orchestration**: k3s
- **GitOps**: ArgoCD (app-of-apps pattern)
- **Load Balancer**: MetalLB (L2 mode, IP pool 192.168.124.200-210)
- **Ingress**: ingress-nginx (gets a MetalLB IP)
- **Monitoring**: Prometheus + Grafana + node-exporter + kube-state-metrics
- **Storage**: NFS from json-lab-1's 8TB drive
- **Router**: Firewalla Gold Pro (DHCP, DNS, firewall, WireGuard VPN)

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

Or via SSH on the Firewalla, add to dnsmasq config:
```
address=/json.lab/192.168.124.200
```

**Note:** Disable DNS-over-HTTPS (DoH) for the LAN network, as DoH bypasses local DNS entries.

### MetalLB IP Pool

MetalLB runs in L2 mode and assigns IPs from `192.168.124.200-192.168.124.210`. Reserve this range in your Firewalla's DHCP settings to avoid conflicts.

## Workloads

- **Jellyfin** — media server (jellyfin.json.lab)
- **Plex** — media server (plex.json.lab)
- **Sonarr** — TV show management (sonarr.json.lab)
- **Radarr** — Movie management (radarr.json.lab)
- **Prowlarr** — Indexer management (prowlarr.json.lab)
- **qBittorrent** — Torrent client with gluetun VPN sidecar (qbittorrent.json.lab)

## Getting Started

### 1. Deploy NixOS to nodes

```bash
# Validate configs
nix flake check ./nixos

# Deploy to a node (run on the target node)
sudo nixos-rebuild switch --flake ./nixos#json-lab-1
```

### 2. Bootstrap the cluster

After k3s is running on all nodes:

```bash
# Copy kubeconfig from json-lab-1
scp jasonwc@192.168.124.10:/etc/rancher/k3s/k3s.yaml ~/.kube/config
# Update the server address
sed -i 's/127.0.0.1/192.168.124.10/' ~/.kube/config

# Deploy MetalLB (provides LoadBalancer IPs)
kubectl apply -k cluster/infrastructure/metallb/

# Deploy ingress-nginx (gets a MetalLB IP automatically)
kubectl apply -k cluster/infrastructure/ingress-nginx/

# Deploy NFS storage
kubectl apply -f cluster/infrastructure/nfs-storage/

# Bootstrap ArgoCD
kubectl apply -k cluster/bootstrap/argocd/
```

### 3. Create secrets (not stored in repo)

Edit `.envrc` with your real credentials, then:

```bash
source .envrc && ./scripts/apply-secrets.sh
```

This creates secrets for VPN credentials, Plex claim token, and Grafana admin password. See `.envrc` for all required variables.

### 4. Deploy apps via ArgoCD

```bash
# Apply ArgoCD Application definitions
kubectl apply -f cluster/apps/

# Access ArgoCD UI
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Storage Layout

```
8TB External Drive (json-lab-1:/mnt/storage)
├── media/
│   ├── movies/        ← Radarr downloads, Plex/Jellyfin reads
│   ├── tv/            ← Sonarr downloads, Plex/Jellyfin reads
│   └── downloads/     ← qBittorrent incomplete + complete
└── config/            ← optional: durable app configs
```

## Monitoring

Prometheus + Grafana are deployed in the `monitoring` namespace.

| Service | URL | Purpose |
|---------|-----|---------|
| Prometheus | prometheus.json.lab | Metrics collection and queries |
| Grafana | grafana.json.lab | Dashboards and visualization |

### What's scraped

- **node-exporter** — CPU, memory, disk, network per node (DaemonSet on all 3 nodes)
- **kube-state-metrics** — pod/deployment/node status
- **kubelet + cAdvisor** — container resource usage
- **k8s API server** — API request metrics
- **ingress-nginx** — request rates, latencies, error rates

### Recommended Grafana dashboards (import by ID)

| Dashboard | Grafana ID |
|-----------|------------|
| Node Exporter Full | 1860 |
| Kubernetes Cluster Overview | 15520 |
| NGINX Ingress Controller | 14314 |

### Phase 2: App-level metrics

After media apps are running, exportarr sidecars can be added to Sonarr, Radarr, Prowlarr, and qBittorrent. These require API keys generated by each app at first run. Commented-out scrape configs are already in the Prometheus ConfigMap.

## Verification

1. `nix flake check ./nixos` — NixOS configs are valid
2. `kubectl apply --dry-run=client -R -f cluster/` — k8s manifests are valid
3. ArgoCD UI shows all apps synced
4. `kubectl exec -n media deploy/qbittorrent -c gluetun -- curl -s ifconfig.me` — shows VPN IP
5. Add a show in Sonarr → triggers download in qBittorrent → appears in Jellyfin/Plex
6. `prometheus.json.lab/targets` — all scrape targets show UP
7. `grafana.json.lab` — login, import dashboard 1860, see node metrics

## Future Improvements

- [ ] SOPS or Sealed Secrets for encrypted secrets in-repo
- [ ] exportarr sidecars for Sonarr/Radarr/Prowlarr metrics
- [ ] Automated backups for app configs
