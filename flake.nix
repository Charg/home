{
  description = "Chris Argeros - chris@syn.sh - Get Flaked";

  inputs = {
    # DANGER: changing is similar to a complete system upgrade/downgrade.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae.url = "github:vicinaehq/vicinae";

  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      disko,
      home-manager,
      darwin,
      ...
    }@inputs:
    let
      overlays = import ./nix/lib/overlays.nix { inherit inputs; };

      mkSystem = import ./nix/lib/mksystem.nix {
        inherit nixpkgs inputs overlays;
      };

    in
    {

      nixosConfigurations.framework = mkSystem "framework" {
        system = "x86_64-linux";
        user = "framework";
        wsl = false;
      };

      nixosConfigurations.wsl = mkSystem "wsl" {
        system = "x86_64-linux";
        user = "framework";
        wsl = true;
      };

      # Colmena managed machine
      nixosConfigurations.nuc01 = mkSystem "nuc01" {
        system = "x86_64-linux";
        user = "nixos";
        wsl = false;
      };

      nixosConfigurations.iso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # specialArgs = { inherit inputs outputs; };
        modules = [
          (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
          ./nix/machines/iso/config.nix
        ];
      };

      darwinConfigurations.mbp-work-1 = mkSystem "mbp-work-1" {
        system = "aarch64-darwin";
        user = "cargeros";
        darwin = true;
      };

    };
}
