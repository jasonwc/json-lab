{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-json-lab-1.nix
    ../modules/k3s.nix
    ../modules/nfs-server.nix
  ];

  # ---------- Hostname ----------
  networking.hostName = "json-lab-1";

  # ---------- Static IP ----------
  networking.interfaces.eno1 = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "192.168.124.10";
      prefixLength = 24;
    }];
  };

  # ---------- 8TB external storage ----------
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/e209c112-d618-4343-8645-1e2c9297cb27";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # ---------- k3s control plane + worker ----------
  homelab.k3s = {
    enable = true;
    role   = "server";
    extraFlags = [
      "--disable=traefik"
      "--write-kubeconfig-mode=644"
      "--tls-san=192.168.124.10"
      "--node-ip=192.168.124.10"
    ];
  };

  # ---------- NFS server ----------
  homelab.nfs-server = {
    enable = true;
    exportPath     = "/mnt/storage/media";
    allowedNetwork = "192.168.124.0/24";
  };
}
