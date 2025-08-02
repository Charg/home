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

  };

  outputs = { self, nixpkgs, nixos-hardware, home-manager, darwin, ... }@inputs:
  let

    mkSystem = import ./lib/mksystem.nix {
      inherit nixpkgs inputs;
    };

  in {

    nixosConfigurations.framework = mkSystem "framework" {
      system = "x86_64-linux";
      user   = "framework";
      wsl    = false;
    };

    nixosConfigurations.wsl = mkSystem "wsl" {
      system = "x86_64-linux";
      user   = "framework";
      wsl    = true;
    };

    nixosConfigurations."USCARGEROS" = mkSystem "mbp-work-1" {
      system = "aarch64-darwin";
      user   = "cargeros";
      darwin = true;
    };
  };
}
