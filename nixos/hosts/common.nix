{ config, pkgs, lib, ... }:

{
  # ---------- Nix settings ----------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "jasonwc" ];
  };

  # ---------- Boot ----------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ---------- Kernel ----------
  # The in-kernel r8169 does not reliably bring up the RTL8125 NIC on these
  # GMKTek boxes.  Use Realtek's out-of-tree r8125 driver instead and blacklist
  # r8169 so it doesn't race.  The nixpkgs r8125 package is marked "broken"
  # (maintainers consider r8169 sufficient), so we override that flag.
  boot.extraModulePackages = with config.boot.kernelPackages; [
    (r8125.overrideAttrs (old: { meta = old.meta // { broken = false; }; }))
  ];
  boot.blacklistedKernelModules = [ "r8169" ];
  boot.kernelModules = [ "br_netfilter" "overlay" "r8125" ];

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
    defaultGateway = "192.168.124.1";

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
  users.users.jasonwc = {
    isNormalUser = true;
    description  = "jasonwc";
    extraGroups  = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOog27hZwOVc7DKG1nSZ/ZkXrKS0NmgCyQQuNeWj/FcY"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  # ---------- Packages ----------
  environment.systemPackages = with pkgs; [
    vim
    curl
    htop
    git
    pciutils
    nfs-utils
    k9s
    kubectl
    jq
  ];

  # ---------- Misc ----------
  system.stateVersion = "24.11";
}
