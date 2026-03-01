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
        json-lab-1 = mkNode {
          hostname = "json-lab-1";
          hostConfig = ./hosts/json-lab-1.nix;
        };

        json-lab-2 = mkNode {
          hostname = "json-lab-2";
          hostConfig = ./hosts/json-lab-2.nix;
        };

        json-lab-3 = mkNode {
          hostname = "json-lab-3";
          hostConfig = ./hosts/json-lab-3.nix;
        };
      };
    };
}
