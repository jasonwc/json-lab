{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/k3s.nix
  ];

  # ---------- Hostname ----------
  networking.hostName = "json-lab-3";

  # ---------- Static IP ----------
  networking.interfaces.enp1s0 = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "192.168.124.12";
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
      "--node-ip=192.168.124.12"
    ];
  };
}
