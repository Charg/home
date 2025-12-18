{
  description = "Chris Argeros - chris@syn.sh - Get Flaked";

  inputs = {
    # DANGER: changing is similar to a complete system upgrade/downgrade.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae.url = "github:vicinaehq/vicinae";

  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      home-manager,
      darwin,
      ...
    }@inputs:
    let

      overlays = [
        (final: prev: {
          tmux = prev.tmux.overrideAttrs (oldAttrs: rec {
            version = "3.6a";
            src = prev.fetchFromGitHub {
              owner = "tmux";
              repo = "tmux";
              rev = version;
              hash = "sha256-VwOyR9YYhA/uyVRJbspNrKkJWJGYFFktwPnnwnIJ97s=";
            };
          });
        })
      ];

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

      darwinConfigurations.mbp-work-1 = mkSystem "mbp-work-1" {
        system = "aarch64-darwin";
        user = "cargeros";
        darwin = true;
      };
    };
}
