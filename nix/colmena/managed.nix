let
  flake = builtins.getFlake (toString ../..);
  inputs = flake.inputs;
  nixpkgs = inputs.nixpkgs;
  overlays = import ../lib/overlays.nix { inherit inputs; };
  mkSystem = import ../lib/mksystem.nix {
    inherit nixpkgs inputs overlays;
  };
in
{
  meta = {
    nixpkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
      overlays = overlays;
    };

    # oci01 is aarch64; everything else uses meta.nixpkgs
    nodeNixpkgs.oci01 = import nixpkgs {
      system = "aarch64-linux";
      config.allowUnfree = true;
      overlays = overlays;
    };
  };

  nuc01 = {
    deployment = {
      targetHost = "nuc01";
      targetUser = "nixos";
      buildOnTarget = true;
      tags = [
        "server"
        "nuc01"
      ];
    };

    imports = mkSystem "nuc01" {
      system = "x86_64-linux";
      user = "nixos";
      wsl = false;
      onlyModules = true;
    };
  };

  mpc00 = {
    deployment = {
      targetHost = "mpc00";
      targetUser = "nixos";
      buildOnTarget = true;
      tags = [
        "server"
        "mpc00"
      ];
    };

    imports = mkSystem "mpc00" {
      system = "x86_64-linux";
      user = "nixos";
      wsl = false;
      onlyModules = true;
    };
  };

  mpc01 = {
    deployment = {
      targetHost = "mpc01";
      targetUser = "nixos";
      buildOnTarget = true;
      tags = [
        "server"
        "mpc01"
      ];
    };

    imports = mkSystem "mpc01" {
      system = "x86_64-linux";
      user = "nixos";
      wsl = false;
      onlyModules = true;
    };
  };

  oci01 = {
    deployment = {
      targetHost = "oci01";
      targetUser = "nixos";
      # aarch64; the control machines are x86_64
      buildOnTarget = true;
      tags = [
        "server"
        "oci01"
      ];
    };

    imports = mkSystem "oci01" {
      system = "aarch64-linux";
      user = "nixos";
      profile = "server";
      wsl = false;
      onlyModules = true;
    };
  };
}
