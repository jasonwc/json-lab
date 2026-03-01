# Firewalla Gold Pro Configuration

Manual configuration steps for the Firewalla Gold Pro router. These settings are not managed by GitOps and must be applied through the Firewalla app or SSH.

## IP Address Plan

The `192.168.124.0/24` subnet is divided as follows:

| Range | Purpose | Count |
|-------|---------|-------|
| `.1` | Firewalla gateway | 1 |
| `.2-.9` | Reserved (future static devices) | 8 |
| `.10-.12` | k3s cluster nodes (DHCP reserved) | 3 |
| `.13-.99` | Reserved (future static devices) | 87 |
| `.100-.199` | DHCP pool (dynamic devices) | 100 |
| `.200-.210` | MetalLB VIPs (k8s services) | 11 |
| `.211-.254` | Free (expand MetalLB or static use) | 44 |

## DHCP Configuration

Set the DHCP pool to avoid the static and MetalLB ranges.

**Firewalla App:** Networks → LAN → DHCP → set:
- **Start IP Address:** `192.168.124.100`
- **End IP Address:** `192.168.124.199`

## DNS: Custom Rules

Route all `*.json.lab` traffic to the MetalLB ingress IP.

**Firewalla App:** Services → Custom DNS Rules → Add:

| Domain | IP |
|--------|-----|
| `*.json.lab` | `192.168.124.200` |

**Or via SSH:**
```bash
echo 'address=/json.lab/192.168.124.200' >> /home/pi/.firewalla/config/dnsmasq_local/json-lab.conf
sudo systemctl restart firerouter_dns
```

### Important: Disable DoH for LAN

DNS-over-HTTPS bypasses local DNS entries. If DoH is enabled for the LAN network, `*.json.lab` will not resolve to the local IP.

**Firewalla App:** DNS → ensure DoH is off for the LAN network (or at minimum, for devices that need to access homelab services).

## Static DHCP Leases

Ensure the cluster nodes always get the same IPs.

| Hostname | MAC Address | IP |
|----------|-------------|-----|
| json-lab-1 | `XX:XX:XX:XX:XX:XX` | 192.168.124.10 |
| json-lab-2 | `XX:XX:XX:XX:XX:XX` | 192.168.124.11 |
| json-lab-3 | `XX:XX:XX:XX:XX:XX` | 192.168.124.12 |

**Firewalla App:** Devices → select node → Network → Reserve IP Address.

> Replace `XX:XX:XX:XX:XX:XX` with actual MAC addresses once hardware is set up.

## WireGuard VPN Server

The Firewalla's built-in WireGuard VPN server provides remote access. When connected via WireGuard, you're on the LAN and can reach `*.json.lab` services through the same DNS path as local clients.

**Firewalla App:** VPN Server → WireGuard → Enable.

No additional configuration needed — the default settings route all traffic through the home network, including DNS.

## Firewall Rules

No special firewall rules are needed for the homelab. All traffic between LAN devices is allowed by default. Relevant ports for reference:

| Port | Protocol | Service |
|------|----------|---------|
| 6443 | TCP | k3s API server (json-lab-1) |
| 80 | TCP | ingress-nginx HTTP (MetalLB IP) |
| 443 | TCP | ingress-nginx HTTPS (MetalLB IP) |
| 2049 | TCP/UDP | NFS (json-lab-1, LAN only) |
