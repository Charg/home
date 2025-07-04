{ nixpkgs, inputs }:

name:
{
  system,
  user,
  darwin ? false,
  wsl ? false,
}:

let
  isWSL = wsl;
  isDarwin = darwin;
  isLinux = !isDarwin && !isWSL;

  # The config files for this system.
  machineConfig = ../machines/${name}/config.nix;
  userOSConfig = ../users/${user}/${if isDarwin then "darwin" else "nixos"}.nix;
  userHMConfig = ../users/${user}/home-manager.nix;

  # NixOS vs nix-darwin functions
  systemFunc = if isDarwin then inputs.darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
  home-manager =
    if isDarwin then inputs.home-manager.darwinModules else inputs.home-manager.nixosModules;
in
systemFunc rec {
  inherit system;

  modules = [
    # Allow unfree packages.
    { nixpkgs.config.allowUnfree = true; }

    # Bring in WSL if this is a WSL build
    (if isWSL then inputs.nixos-wsl.nixosModules.wsl else { })

    # Load Hardware Module(s)
    # TODO: can I move this into the machineConfig?
    (if name == "framework" then inputs.nixos-hardware.nixosModules.framework-13-7040-amd else { })

    machineConfig
    userOSConfig
    home-manager.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${user} = userHMConfig;
      home-manager.extraSpecialArgs = {
        currentSystemName = name;
        inputs = inputs;
        isDarwin = isDarwin;
        isLinux = isLinux;
        isWSL = isWSL;
      };
    }

    # {
    #   config._module.args = {
    #     currentSystem = system;
    #     currentSystemName = name;
    #     currentSystemUser = user;
    #     isWSL = isWSL;
    #     inputs = inputs;
    #   };
    # }

  ];
}
