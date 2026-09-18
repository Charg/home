{
  nixpkgs,
  inputs,
  overlays,
}:

name:
{
  system,
  user,
  darwin ? false,
  wsl ? false,

  # If true, only return the list of modules, without calling darwinSystem or nixosSystem.
  # OnlyModules is primarily used when performing a colmena deployment.
  onlyModules ? false,
}:

let
  lib = nixpkgs.lib;
  isWSL = wsl;
  isDarwin = darwin;
  isLinux = !isDarwin && !isWSL;

  # A plain nixpkgs-unstable package set, handed to modules as `unstable-pkgs`
  # so they can reach for e.g. `unstable-pkgs.wtp` directly instead of adding
  # an overlay just to pull one package forward from unstable.
  unstable-pkgs = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };

  # The config files for this system.
  machineConfig = ../machines/${name}/config.nix;
  userOSConfig = ../users/${user}/${if isDarwin then "darwin" else "nixos"}.nix;
  userHMConfig = ../users/${user}/home-manager.nix;

  # System function to call in the end. Either darwinSystem or nixosSystem, depending on the platform.
  systemBuilder = if isDarwin then inputs.darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;

  homeManagerModules =
    if isDarwin then inputs.home-manager.darwinModules else inputs.home-manager.nixosModules;

  modules = [
    { nixpkgs.overlays = overlays; }
    {
      nixpkgs.config.allowUnfree = true;
      nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];
    }

    machineConfig
    userOSConfig
    homeManagerModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${user} = userHMConfig;
      home-manager.sharedModules = [
        inputs.sops-nix.homeManagerModules.sops
        {
          # sops-install-secrets' go.mod now needs a newer Go than nixos-25.11 ships;
          # build it with nixpkgs-unstable's toolchain instead of the system's.
          sops.package = (import inputs.sops-nix { pkgs = unstable-pkgs; }).sops-install-secrets;
        }
      ];
      home-manager.extraSpecialArgs = {
        currentSystemName = name;
        currentSystemUser = user;
        inputs = inputs;
        isDarwin = isDarwin;
        isLinux = isLinux;
        isWSL = isWSL;
        unstable-pkgs = unstable-pkgs;
      };
    }

    {
      config._module.args = {
        currentSystem = system;
        currentSystemName = name;
        currentSystemUser = user;
        isWSL = isWSL;
        inputs = inputs;
        unstable-pkgs = unstable-pkgs;
      };
    }

  ]
  ++ lib.optionals (!isDarwin) [
    inputs.disko.nixosModules.disko
  ]
  ++ lib.optionals isWSL [
    inputs.nixos-wsl.nixosModules.wsl
  ]
  ++ lib.optionals isDarwin [
    inputs.darwin.darwinModules.simple
  ];
in
# Return either the list of modules or the result of calling darwinSystem/nixosSystem with those modules.
if onlyModules then
  modules
else
  systemBuilder {
    inherit system modules;
  }
