{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-json-lab-2.nix
    ../modules/k3s.nix
  ];

  # ---------- Hostname ----------
  networking.hostName = "json-lab-2";

  # ---------- Static IP ----------
  networking.interfaces.eno1 = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "192.168.124.11";
      prefixLength = 24;
    }];
  };

  # ---------- k3s worker ----------
  homelab.k3s = {
    enable     = true;
    role       = "agent";
    serverAddr = "https://192.168.124.10:6443";
    tokenFile  = "/etc/k3s/token";
    extraFlags = [
      "--node-ip=192.168.124.11"
    ];
  };
}
