{ config, pkgs, lib, ... }:

let
  cfg = config.homelab.nfs-server;
in
{
  options.homelab.nfs-server = {
    enable = lib.mkEnableOption "NFS server for cluster-shared storage";

    exportPath = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/storage/media";
      description = "Local path to export over NFS.";
    };

    allowedNetwork = lib.mkOption {
      type = lib.types.str;
      default = "192.168.124.0/24";
      description = "Network CIDR allowed to mount the export.";
    };

    exportOptions = lib.mkOption {
      type = lib.types.str;
      default = "rw,sync,no_subtree_check,no_root_squash";
      description = "NFS export options.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nfs.server = {
      enable = true;
      exports = ''
        ${cfg.exportPath}  ${cfg.allowedNetwork}(${cfg.exportOptions})
      '';
    };

    # Ensure the export directory exists.
    systemd.tmpfiles.rules = [
      "d ${cfg.exportPath} 0775 root root -"
    ];

    networking.firewall.allowedTCPPorts = [
      2049  # NFS
      111   # rpcbind / portmapper
    ];

    networking.firewall.allowedUDPPorts = [
      2049
      111
    ];
  };
}
