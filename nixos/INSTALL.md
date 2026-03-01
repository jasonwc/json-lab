# NixOS Installation Guide

Step-by-step instructions for installing NixOS on each json-lab node from the USB installer.

## Prerequisites

- NixOS installer USB (flashed and ready)
- Each node connected to the network via ethernet
- A monitor and keyboard (can be shared, one node at a time)
- Your SSH public key (to paste into common.nix before deploying)

## Step 1: Boot from USB

1. Plug the USB installer into the node
2. Power on and press **Del** or **F7** repeatedly to enter BIOS/boot menu
   - **Del/F2** = BIOS setup (change boot order)
   - **F7/F11** = one-time boot menu (pick USB directly)
3. Select the USB drive and boot into the NixOS installer
4. Switch to root — the installer starts as the `nixos` user:
   ```bash
   sudo -i
   ```
5. Connect to WiFi (the GMKTek ethernet NIC is not detected by the installer):
   ```bash
   nmcli device wifi connect "YourSSID" password "YourPassword"
   ping -c 3 cache.nixos.org  # verify connectivity
   ```

## Step 2: Identify the disk

```bash
lsblk
```

Look for the internal NVMe or SATA drive (not the USB). It will typically be:
- `/dev/nvme0n1` (NVMe SSD)
- `/dev/sda` (SATA SSD)

The examples below use `/dev/nvme0n1`. Replace with your actual device.

## Step 3: Partition the disk

We'll create a simple GPT layout: a 512MB EFI boot partition and the rest as root.

```bash
# Wipe and create a fresh GPT partition table
parted /dev/nvme0n1 -- mklabel gpt

# Create the EFI System Partition (512MB)
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 513MiB
parted /dev/nvme0n1 -- set 1 esp on

# Create the root partition (remaining space)
parted /dev/nvme0n1 -- mkpart primary ext4 513MiB 100%
```

## Step 4: Format the partitions

```bash
# Format EFI partition
mkfs.fat -F 32 -n boot /dev/nvme0n1p1

# Format root partition
mkfs.ext4 -L nixos /dev/nvme0n1p2
```

## Step 5: Mount and generate config

```bash
# Mount root
mount /dev/disk/by-label/nixos /mnt

# Create and mount boot
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

# Generate hardware config
nixos-generate-config --root /mnt
```

This creates two files:
- `/mnt/etc/nixos/configuration.nix` — default config (we'll replace this with our flake)
- `/mnt/etc/nixos/hardware-configuration.nix` — auto-detected hardware (keep this)

## Step 6: Install the base system

For the initial install, we'll use the generated config as-is to get a bootable system. Edit the generated config to enable SSH and set a password so you can access the node after reboot:

```bash
nano /mnt/etc/nixos/configuration.nix
```

Make sure these are set:

```nix
{
  # Enable SSH so you can access remotely after reboot
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";

  # Set a temporary root password (we'll disable this later via flake config)
  users.users.root.initialPassword = "nixos";

  # Create your user with a temporary password
  users.users.jasonwc = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "nixos";
  };

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

Then install:

```bash
nixos-install
```

When prompted, set the root password (temporary — will be managed by flake config later).

Reboot and remove the USB:

```bash
reboot
```

After reboot, log in as `jasonwc` (password: `nixos`) and reconnect WiFi:

```bash
sudo nmcli device wifi connect "YourSSID" password "YourPassword"
```

## Step 7: Switch to flake config

After reboot, log in (locally or via SSH using the temporary password) and deploy the flake config.

### 7a. Copy hardware-configuration.nix

The generated `hardware-configuration.nix` contains hardware-specific settings (disk UUIDs, kernel modules, etc.) that your flake needs. Copy it into the json-lab repo:

```bash
# From your dev machine (json-mini), copy it over
scp jasonwc@<node-dhcp-ip>:/etc/nixos/hardware-configuration.nix \
  nixos/hosts/hardware-json-lab-1.nix  # (or -2, -3)
```

Then add it as an import in the node's config file (e.g. `json-lab-1.nix`):

```nix
imports = [
  ./hardware-json-lab-1.nix
  ../modules/k3s.nix
  ../modules/nfs-server.nix
];
```

### 7b. Verify network interface name

```bash
ip link
```

If the ethernet interface is NOT `enp1s0`, update the node's nix config to match the actual interface name.

### 7c. Add your SSH public key

Edit `nixos/hosts/common.nix` and replace the TODO with your actual SSH public key:

```nix
openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA... jasonwc@json-mini"
];
```

### 7d. Clone the repo and deploy

Git isn't available on the base install. Use `nix-shell` to get it temporarily:

```bash
# On the node — get git in a temporary shell
nix-shell -p git

# Clone and deploy
git clone https://github.com/jasonwc/json-lab.git ~/json-lab
cd ~/json-lab
sudo nixos-rebuild switch --flake ./nixos#json-lab-1
```

After `nixos-rebuild switch`, git (and all other packages in `common.nix`) will be permanently installed.

### 7e. Reboot and verify ethernet

```bash
sudo reboot
```

After reboot, the r8125 driver should load and the ethernet NIC will be available. Verify:

```bash
ip link  # look for the ethernet interface (e.g. enp1s0)
ip addr  # confirm the static IP is assigned
```

If the ethernet interface name is NOT `enp1s0`, update the node's nix config to match, commit, and re-run `nixos-rebuild switch`.

**Important:** After this deploy, SSH password auth is disabled. Make sure your SSH key was added to `common.nix` before deploying, or you'll need physical access to recover.

## Per-Node Notes

### json-lab-1 (192.168.124.10) — Control Plane

Do everything above, plus:

1. **Plug in the 8TB USB drive** and find its UUID:
   ```bash
   lsblk -f
   ```
   Look for the 8TB device (likely `/dev/sda1`).

2. **Format it** (only if new/unformatted):
   ```bash
   mkfs.ext4 -L storage /dev/sda1
   ```

3. **Get the UUID** and update `json-lab-1.nix`:
   ```bash
   sudo blkid /dev/sda1
   ```
   Replace `REPLACE-WITH-ACTUAL-UUID` in the config with the actual UUID.

   **Note:** The WD Elements drive ships as NTFS. Format it to ext4 before use.

4. **Create the media directory** after the drive is mounted:
   ```bash
   sudo mkdir -p /mnt/storage/media/{movies,tv,downloads}
   ```

5. **Save the k3s token** for the worker nodes:
   ```bash
   # After k3s starts, copy the token
   sudo cat /var/lib/rancher/k3s/server/node-token
   ```

### json-lab-2 (192.168.124.11) — Worker

1. Complete steps 1-7 using `json-lab-2` as the flake target:
   ```bash
   sudo nixos-rebuild switch --flake ./nixos#json-lab-2
   ```

2. **Copy the k3s token** from json-lab-1:
   ```bash
   sudo mkdir -p /etc/k3s
   echo "<token-from-json-lab-1>" | sudo tee /etc/k3s/token
   ```

3. k3s will automatically join the cluster as a worker.

### json-lab-3 (192.168.124.12) — Worker

Same as json-lab-2, but use `json-lab-3`:

```bash
sudo nixos-rebuild switch --flake ./nixos#json-lab-3
```

And copy the same k3s token to `/etc/k3s/token`.

## Verification

After all three nodes are deployed:

```bash
# From json-mini (or any machine with kubectl configured)
kubectl get nodes
```

Expected output:
```
NAME         STATUS   ROLES                  AGE   VERSION
json-lab-1   Ready    control-plane,master   XXm   v1.xx.x+k3s1
json-lab-2   Ready    <none>                 XXm   v1.xx.x+k3s1
json-lab-3   Ready    <none>                 XXm   v1.xx.x+k3s1
```

## Install Order

1. **json-lab-1 first** — it runs the k3s control plane and generates the join token
2. **json-lab-2 and json-lab-3** — can be done in parallel after json-lab-1 is up

## Debugging

Issues encountered during the initial json-lab-1 install and their solutions.

### No network in the installer

The GMKTek Mini PCs use a **Realtek RTL8125 2.5GbE** NIC (PCI ID `10ec:8125`). The NixOS installer kernel does not include a working driver for it — the in-kernel `r8169` driver claims the device but does not bring up the interface.

**Workaround:** Use WiFi during installation (`nmcli device wifi connect "SSID" password "pass"`). The flake config includes the out-of-tree `r8125` driver package, so ethernet works after the first `nixos-rebuild switch` and reboot.

**How we diagnosed it:**
```bash
cat /proc/bus/pci/devices | grep 8125   # confirmed Realtek RTL8125
ls /sys/class/net/                       # only lo and wlp1s0 (no ethernet)
sudo modprobe r8169                      # loaded but no new interface appeared
```

### "Not superuser" errors in the installer

The NixOS installer boots as the `nixos` user, not root. Run `sudo -i` first before partitioning or installing.

### lspci / pciutils not found

The base NixOS install doesn't include `pciutils`. Use `nix-shell -p pciutils` for a temporary install, or it'll be available after deploying the flake (included in `common.nix`).

### FAT32 /boot "world accessible" warning

During `nixos-install`, you may see a warning about `/boot` being world-accessible. This is informational only — it's normal for FAT32 EFI partitions which don't support Unix permissions. Safe to ignore.

### git not available on fresh install

The base NixOS install doesn't include git. Use `nix-shell -p git` to get it temporarily for the initial clone. After `nixos-rebuild switch`, git is permanently installed via `common.nix`.

### WD Elements 8TB drive is NTFS

The drive ships formatted as NTFS. Reformat to ext4 before use:
```bash
sudo mkfs.ext4 -L storage /dev/sda1
```
