{
  description = "k3s homelab — 3x GMKTek Mini PC (Ryzen 5 3500) cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";

      mkNode = { hostname, hostConfig }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/common.nix
            hostConfig
          ];
        };
    in
    {
      nixosConfigurations = {
        node1 = mkNode {
          hostname = "node1";
          hostConfig = ./hosts/node1.nix;
        };

        node2 = mkNode {
          hostname = "node2";
          hostConfig = ./hosts/node2.nix;
        };

        node3 = mkNode {
          hostname = "node3";
          hostConfig = ./hosts/node3.nix;
        };
      };
    };
}
