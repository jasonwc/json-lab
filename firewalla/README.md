# Firewalla Gold Pro Configuration

Manual configuration steps for the Firewalla Gold Pro router. These settings are not managed by GitOps and must be applied through the Firewalla app or SSH.

## DHCP Reserved Range

Reserve `192.168.1.200-192.168.1.210` so DHCP does not assign these IPs to devices. MetalLB uses this range for Kubernetes LoadBalancer services.

**Firewalla App:** Networks → LAN → DHCP → set range to avoid 200-210 (e.g. `192.168.1.100-192.168.1.199`).

## DNS: Custom Rules

Route all `*.json.lab` traffic to the MetalLB ingress IP.

**Firewalla App:** Services → Custom DNS Rules → Add:

| Domain | IP |
|--------|-----|
| `*.json.lab` | `192.168.1.200` |

**Or via SSH:**
```bash
echo 'address=/json.lab/192.168.1.200' >> /home/pi/.firewalla/config/dnsmasq_local/json-lab.conf
sudo systemctl restart firerouter_dns
```

### Important: Disable DoH for LAN

DNS-over-HTTPS bypasses local DNS entries. If DoH is enabled for the LAN network, `*.json.lab` will not resolve to the local IP.

**Firewalla App:** DNS → ensure DoH is off for the LAN network (or at minimum, for devices that need to access homelab services).

## Static DHCP Leases

Ensure the cluster nodes always get the same IPs.

| Hostname | MAC Address | IP |
|----------|-------------|-----|
| node1 | `XX:XX:XX:XX:XX:XX` | 192.168.1.10 |
| node2 | `XX:XX:XX:XX:XX:XX` | 192.168.1.11 |
| node3 | `XX:XX:XX:XX:XX:XX` | 192.168.1.12 |

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
| 6443 | TCP | k3s API server (node1) |
| 80 | TCP | ingress-nginx HTTP (MetalLB IP) |
| 443 | TCP | ingress-nginx HTTPS (MetalLB IP) |
| 2049 | TCP/UDP | NFS (node1, LAN only) |
