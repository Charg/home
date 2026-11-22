{
  nixpkgs,
  inputs,
  overlays,
}:

{
  host,
  # nix/roles/<role>.nix: everything about the machine's purpose.
  role,
  # nix/users/<home>: the user's account (nixos.nix, optional) and Home
  # Manager config. Several hosts, and account names, can share one.
  home ? null,
  # Include Home Manager without a `home` setup, for users the machine
  # config declares itself.
  homeManager ? false,
  # { system; home ? null; }
  stateVersion,
}:

let
  inherit (nixpkgs) lib;

  # The config files for this system.
  machineConfig = ../machines/${host.name}/config.nix;
  hasHome = home != null;
  userAccount = ../users/${home}/nixos.nix;
  userHMConfig = ../users/${home}/home-manager.nix;

  # System function to call in the end. Either darwinSystem or nixosSystem, depending on the platform.
  systemBuilder = if host.isDarwin then inputs.darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;

  homeManagerModules =
    if host.isDarwin then inputs.home-manager.darwinModules else inputs.home-manager.nixosModules;

  modules = [
    { nixpkgs.overlays = overlays; }
    { nixpkgs.config.allowUnfree = true; }

    machineConfig
    { system.stateVersion = stateVersion.system; }
  ]
  ++ lib.optionals (hasHome || homeManager) [
    homeManagerModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.sharedModules = [
        inputs.sops-nix.homeManagerModules.sops
      ];
      home-manager.extraSpecialArgs = { inherit inputs host; };
    }
  ]
  ++ lib.optionals hasHome [
    {
      home-manager.users.${host.user} = userHMConfig;
    }
    {
      home-manager.users.${host.user}.home.stateVersion = stateVersion.home;
    }
  ]
  ++ [ ../roles/${role}.nix ]
  ++ lib.optional (hasHome && builtins.pathExists userAccount) userAccount
  ++ lib.optionals (!host.isDarwin) [
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
  ]
  ++ lib.optionals host.isWSL [
    inputs.nixos-wsl.nixosModules.wsl
  ];
in
systemBuilder {
  inherit (host) system;
  inherit modules;
  # Special args, unlike `_module.args`, can be used in `imports`.
  specialArgs = { inherit inputs host; };
}
