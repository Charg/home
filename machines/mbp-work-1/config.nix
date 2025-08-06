{
  config,
  pkgs,
  inputs,
  currentSystem,
  ...
}:

{
  #
  # System
  #
  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  programs.zsh.enable = true;

  services.openssh.enable = true;

  system.defaults.NSGlobalDomain.KeyRepeat = 2;
  system.defaults.NSGlobalDomain.AppleInterfaceStyle = "Dark";
  system.defaults.dock.autohide = true;
  system.defaults.dock.mru-spaces = false;
  system.defaults.dock.show-recents = false;
  system.defaults.dock.tilesize = 30;

  nixpkgs.hostPlatform = currentSystem;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
