{ config, pkgs, lib, ... }:

let
  cfg = config.homelab.k3s;
in
{
  options.homelab.k3s = {
    enable = lib.mkEnableOption "k3s Kubernetes distribution";

    role = lib.mkOption {
      type = lib.types.enum [ "server" "agent" ];
      description = "Whether this node runs as a k3s server (control plane) or agent (worker).";
    };

    serverAddr = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Address of the k3s server to join. Required for agents; leave empty for the initial server.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/k3s/token";
      description = "Path to the file containing the k3s cluster token.";
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra command-line flags passed to the k3s process.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      enable = true;
      role   = cfg.role;

      serverAddr = lib.mkIf (cfg.serverAddr != "") cfg.serverAddr;
      tokenFile  = lib.mkIf (cfg.role == "agent") cfg.tokenFile;

      extraFlags = lib.concatStringsSep " " cfg.extraFlags;
    };

    # k3s nodes need these ports open in addition to the common set.
    networking.firewall = {
      allowedTCPPorts = [
        6443   # API server
        10250  # kubelet
        2379   # etcd client (server nodes)
        2380   # etcd peer   (server nodes)
        9100   # node-exporter (Prometheus scraping)
      ];
      allowedUDPPorts = [
        8472   # flannel VXLAN
        51820  # WireGuard
      ];
    };

    # Ensure the token directory exists.
    systemd.tmpfiles.rules = [
      "d /etc/k3s 0750 root root -"
    ];
  };
}
