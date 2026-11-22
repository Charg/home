{
  nixpkgs,
  home-manager,
  inputs,
  overlays,
}:

{
  host,
  # nix/users/<home>/home-manager.nix
  home,
  stateVersion,
}:

home-manager.lib.homeManagerConfiguration {
  pkgs = import nixpkgs {
    inherit (host) system;
    config.allowUnfree = true;
    inherit overlays;
  };

  extraSpecialArgs = { inherit inputs host; };

  modules = [
    {
      home.username = host.user;
      home.homeDirectory = if host.isDarwin then "/Users/${host.user}" else "/home/${host.user}";
      home.stateVersion = stateVersion.home;
    }
    ../users/${home}/home-manager.nix
  ];
}
