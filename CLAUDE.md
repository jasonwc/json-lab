# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

json-lab — GitOps-managed k3s homelab running on 3 GMKTek Mini PCs (Ryzen 5 3500) with NixOS.

## Architecture

- **3 nodes**: node1 (control plane + worker + 8TB storage), node2/node3 (workers)
- **OS**: NixOS (flake-based configs in `nixos/`)
- **Orchestration**: k3s (Traefik disabled, using ingress-nginx)
- **GitOps**: ArgoCD with app-of-apps pattern
- **Storage**: 8TB external drive on node1, exported via NFS to the cluster
- **Workloads**: Media stack (Jellyfin, Plex, Sonarr, Radarr, Prowlarr, qBittorrent+gluetun VPN)

## Repository Layout

```
nixos/              # NixOS flake configs for all 3 nodes
cluster/
  bootstrap/argocd/ # ArgoCD installation manifests
  apps/             # ArgoCD Application CRDs (app-of-apps)
  infrastructure/   # Cluster infra (NFS storage, ingress-nginx)
  media-stack/      # Media app deployments, services, ingresses
```

## Key Commands

- `nix flake check ./nixos` — validate NixOS configurations
- `nixos-rebuild switch --flake ./nixos#<hostname>` — deploy NixOS config to a node
- `kubectl apply --dry-run=client -f cluster/` — validate k8s manifests
- `kubectl apply -k cluster/bootstrap/argocd/` — bootstrap ArgoCD

## Conventions

- Kubernetes manifests use plain YAML (no Helm for app workloads)
- ArgoCD kustomize-based bootstrap; Application CRDs for app management
- Secrets are NOT committed to the repo; created manually or via SOPS (future)
- NFS PVs for shared media storage; local-path PVCs for per-app config
- VPN sidecar (gluetun) on qBittorrent; all torrent traffic exits via VPN
- Node hostnames: `node1`, `node2`, `node3`
- Media namespace: `media`
- Domain pattern: `<app>.json.lab` for ingresses
