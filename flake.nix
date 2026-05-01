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
      lib = nixpkgs.lib;
      overlays = import ./nix/lib/overlays.nix { inherit inputs; };

      mkSystem = import ./nix/lib/mksystem.nix {
        inherit nixpkgs inputs overlays;
      };

      mkHome = import ./nix/lib/mkhome.nix {
        inherit
          nixpkgs
          home-manager
          inputs
          overlays
          ;
      };

      mkSystemFor =
        name: cfg:
        mkSystem name {
          inherit (cfg) system user;
          darwin = cfg.darwin or false;
          wsl = cfg.wsl or false;
        };

      hosts = {
        framework = {
          system = "x86_64-linux";
          user = "framework";
          home = true;
        };

        wsl = {
          system = "x86_64-linux";
          user = "framework";
          home = true;
          wsl = true;
        };

        nuc01 = {
          system = "x86_64-linux";
          user = "nixos";
        };

        mbp-work-1 = {
          system = "aarch64-darwin";
          user = "cargeros";
          home = true;
        };
      };

      isDarwin = cfg: lib.hasSuffix "darwin" cfg.system;
      isLinux = cfg: lib.hasSuffix "linux" cfg.system;
      isHome = cfg: cfg.home or false;

      nixosHosts = lib.filterAttrs (_: isLinux) hosts;
      darwinHosts = lib.filterAttrs (_: isDarwin) hosts;
      homeHosts = lib.filterAttrs (_: isHome) hosts;

    in
    {
      nixosConfigurations = lib.mapAttrs mkSystemFor nixosHosts // {
        iso = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./nix/machines/iso/config.nix
          ];
        };
      };

      darwinConfigurations = lib.mapAttrs mkSystemFor darwinHosts;

      homeConfigurations = lib.mapAttrs' (name: cfg: {
        name = "${cfg.user}@${name}";
        value = mkHome name {
          inherit (cfg) system user;
          darwin = isDarwin cfg;
          wsl = cfg.wsl or false;
        };
      }) homeHosts;
    };
}
