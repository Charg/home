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
    { nixpkgs.config.allowUnfree = true; }

    inputs.disko.nixosModules.disko

    machineConfig
    userOSConfig
    homeManagerModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${user} = userHMConfig;
      home-manager.extraSpecialArgs = {
        currentSystemName = name;
        currentSystemUser = user;
        inputs = inputs;
        isDarwin = isDarwin;
        isLinux = isLinux;
        isWSL = isWSL;
      };
    }

    {
      config._module.args = {
        currentSystem = system;
        currentSystemName = name;
        currentSystemUser = user;
        isWSL = isWSL;
        inputs = inputs;
      };
    }

  ]
  ++ lib.optionals isWSL [
    inputs.nixos-wsl.nixosModules.wsl
  ]
  ++ lib.optionals isDarwin [
    inputs.darwin.nixosModules.darwin
  ];
in
# Return either the list of modules or the result of calling darwinSystem/nixosSystem with those modules.
if onlyModules then
  modules
else
  systemBuilder {
    inherit system modules;
  }
