{
  description = "Chris Argeros - chris@syn.sh - Get Flaked";

  inputs = {
    # DANGER: changing is similar to a complete system upgrade/downgrade.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
      # Only used by its non-flake entry point.
      inputs.flake-compat.follows = "";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.stable.follows = "nixpkgs";
      # CI helper for colmena's own repo.
      inputs.nix-github-actions.follows = "";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
      # Development hooks for lanzaboote's own repo.
      inputs.pre-commit.follows = "";
    };

    # Game stream host for tortuga, built from the fork's HDR integration
    # branch (sway HDR virtual displays + HDR capture) until those changes
    # land upstream. The package normally fetches its own pinned release
    # source; helios.nix builds this input instead. It must be a remote URL so
    # Renovate and CI can fetch it. After pushing to the branch:
    # `nix flake update helios`.
    helios = {
      url = "github:Charg/helios/feat/sway-hdr";
      flake = false;
    };

    # Moonshine game stream host for tortuga, tried alongside Helios. Its
    # module builds the package against the host's nixpkgs; follows only
    # avoids fetching a second nixpkgs.
    moonshine = {
      url = "github:hgaiser/moonshine";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };

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
      inherit (nixpkgs) lib;
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

      hostFor = name: cfg: import ./nix/lib/host.nix name cfg;

      mkSystemFor =
        name: cfg:
        mkSystem {
          host = hostFor name cfg;
          inherit (cfg) role stateVersion;
          home = cfg.home or null;
          homeManager = cfg.homeManager or false;
        };

      # Every machine. `role` picks the nix/roles module it is built on and
      # `home`, if set, the nix/users/<home> setup for its user (account and
      # Home Manager); only hosts with a `home` (or `homeManager`) include Home
      # Manager. `stateVersion` holds the system and Home Manager state
      # versions. Hosts with `standaloneHome` also get a homeConfigurations
      # entry; hosts with `colmena` are in the Colmena hive.
      hosts = {
        framework = {
          system = "x86_64-linux";
          user = "chris";
          role = "workstation";
          home = "framework";
          standaloneHome = true;
          stateVersion = {
            system = "24.11";
            home = "24.11";
          };
        };

        wsl = {
          system = "x86_64-linux";
          user = "framework";
          role = "wsl";
          home = "framework";
          standaloneHome = true;
          wsl = true;
          stateVersion = {
            system = "24.11";
            home = "24.11";
          };
        };

        tortuga = {
          system = "x86_64-linux";
          user = "chris";
          role = "workstation";
          home = "framework";
          standaloneHome = true;
          # Home Manager state predates this install; bumping it is a behaviour change.
          stateVersion = {
            system = "26.05";
            home = "24.11";
          };
        };

        nuc01 = {
          system = "x86_64-linux";
          user = "nixos";
          role = "k3s-node";
          colmena.tags = [ "server" ];
          stateVersion.system = "25.11";
        };

        mpc00 = {
          system = "x86_64-linux";
          user = "nixos";
          role = "k3s-node";
          colmena.tags = [ "server" ];
          # Home Manager for the dev user (machine config), not host.user.
          homeManager = true;
          stateVersion.system = "25.11";
        };

        mpc01 = {
          system = "x86_64-linux";
          user = "nixos";
          role = "k3s-node";
          colmena.tags = [ "server" ];
          stateVersion.system = "25.11";
        };

        oci01 = {
          system = "aarch64-linux";
          user = "nixos";
          role = "server";
          colmena.tags = [ "server" ];
          stateVersion.system = "26.05";
        };

        mbp-work-1 = {
          system = "aarch64-darwin";
          user = "cargeros";
          role = "darwin";
          home = "cargeros";
          standaloneHome = true;
          stateVersion = {
            system = 6;
            home = "25.05";
          };
        };
      };

      isDarwin = cfg: lib.hasSuffix "darwin" cfg.system;
      isLinux = cfg: lib.hasSuffix "linux" cfg.system;
      isHome = cfg: cfg.standaloneHome or false;
      isColmena = cfg: cfg ? colmena;

      nixosHosts = lib.filterAttrs (_: isLinux) hosts;
      darwinHosts = lib.filterAttrs (_: isDarwin) hosts;
      homeHosts = lib.filterAttrs (_: isHome) hosts;
      colmenaHosts = lib.filterAttrs (_: isColmena) nixosHosts;

      # Every system a host runs on, with the hosts' overlays and config.
      systems = lib.unique (lib.mapAttrsToList (_: cfg: cfg.system) hosts);
      forAllSystems =
        f:
        lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system overlays;
              config.allowUnfree = true;
            }
          )
        );

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

      # Hosts with a `colmena` entry, deployed with exactly the modules and
      # special args of their nixosConfigurations. Nixpkgs is passed bare;
      # overlays and config come from the modules.
      colmenaHive = inputs.colmena.lib.makeHive (
        {
          meta = {
            nixpkgs = import nixpkgs { system = "x86_64-linux"; };
            nodeNixpkgs = lib.mapAttrs (_: cfg: import nixpkgs { inherit (cfg) system; }) colmenaHosts;
            nodeSpecialArgs = lib.mapAttrs (
              name: _: self.nixosConfigurations.${name}._module.specialArgs
            ) colmenaHosts;
          };
        }
        // lib.mapAttrs (name: cfg: {
          deployment = {
            targetHost = name;
            targetUser = cfg.user;
            buildOnTarget = true;
          }
          // cfg.colmena
          // {
            tags = (cfg.colmena.tags or [ ]) ++ [ name ];
          };
          imports = self.nixosConfigurations.${name}._module.args.modules ++ [
            {
              # Colmena evaluates through nixpkgs' eval-config without the
              # flake's lib, which would label the system "pre-git".
              system.nixos = {
                inherit (self.nixosConfigurations.${name}.config.system.nixos) versionSuffix revision;
              };
            }
          ];
        }) colmenaHosts
      );

      # nix/packages, the same derivations hosts get as `pkgs.local`.
      packages = forAllSystems (
        pkgs: lib.filterAttrs (_: lib.meta.availableOn pkgs.stdenv.hostPlatform) pkgs.local
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      checks = forAllSystems (pkgs: import ./nix/lib/checks.nix { inherit self pkgs; });

      # Tools the just recipes and pre-commit hooks expect.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [
            pkgs.just
            pkgs.jq
            pkgs.curl
            pkgs.perl
            pkgs.git
            pkgs.unstable.prek
            pkgs.nixfmt
            pkgs.nixfmt-tree
            pkgs.statix
            pkgs.deadnix
            pkgs.sops
            pkgs.nix-diff
            inputs.colmena.packages.${pkgs.stdenv.hostPlatform.system}.colmena
          ];
        };
      });

      homeConfigurations = lib.mapAttrs' (name: cfg: {
        name = "${cfg.user}@${name}";
        value = mkHome {
          host = hostFor name cfg;
          inherit (cfg) home stateVersion;
        };
      }) homeHosts;
    };
}
