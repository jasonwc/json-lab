{ config, pkgs, lib, ... }:

{
  # ---------- Nix settings ----------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "jason" ];
  };

  # ---------- Boot / kernel ----------
  boot.kernelModules = [ "br_netfilter" "overlay" ];

  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables"  = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward"                 = 1;
  };

  # ---------- Locale / timezone ----------
  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "en_US.UTF-8";
  };

  # ---------- Networking (common) ----------
  networking = {
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    defaultGateway = "192.168.1.1";

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22     # SSH
        6443   # k3s API server
        10250  # kubelet metrics
      ];
      allowedUDPPorts = [
        8472   # flannel VXLAN
        51820  # WireGuard (flannel backend / VPN)
      ];
    };
  };

  # ---------- SSH ----------
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # ---------- Users ----------
  users.users.jason = {
    isNormalUser = true;
    description  = "Jason";
    extraGroups  = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      # TODO: paste your public SSH key here
      # "ssh-ed25519 AAAA..."
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  # ---------- Packages ----------
  environment.systemPackages = with pkgs; [
    vim
    curl
    htop
    git
    nfs-utils
    k9s
    kubectl
    jq
  ];

  # ---------- Misc ----------
  system.stateVersion = "24.11";
}
