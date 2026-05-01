{
  nixpkgs,
  home-manager,
  inputs,
  overlays,
}:

name:
{
  system,
  user,
  darwin ? false,
  wsl ? false,
}:

home-manager.lib.homeManagerConfiguration {
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    inherit overlays;
  };

  extraSpecialArgs = {
    currentSystemName = name;
    currentSystemUser = user;
    inherit inputs;
    isDarwin = darwin;
    isWSL = wsl;
    isLinux = !darwin && !wsl;
  };

  modules = [
    {
      home.username = user;
      home.homeDirectory = if darwin then "/Users/${user}" else "/home/${user}";
    }
    ../users/${user}/home-manager.nix
  ];
}
