{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/k3s.nix
    ../modules/nfs-server.nix
  ];

  # ---------- Hostname ----------
  networking.hostName = "node1";

  # ---------- Static IP ----------
  networking.interfaces.enp1s0 = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "192.168.1.10";
      prefixLength = 24;
    }];
  };

  # ---------- 8TB external storage ----------
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-ACTUAL-UUID";
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
      "--tls-san=192.168.1.10"
      "--node-ip=192.168.1.10"
    ];
  };

  # ---------- NFS server ----------
  homelab.nfs-server = {
    enable = true;
    exportPath     = "/mnt/storage/media";
    allowedNetwork = "192.168.1.0/24";
  };
}
