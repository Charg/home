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

  # MacOS Settings
  system.defaults = {
    NSGlobalDomain.KeyRepeat = 2;

    # Enable repeat key presses
    NSGlobalDomain.AppleInterfaceStyle = "Dark";

    # Dark mode
    NSGlobalDomain.ApplePressAndHoldEnabled = false;

    NSGlobalDomain."com.apple.swipescrolldirection" = false;

    CustomUserPreferences = {
      "com.microsoft.VSCode".ApplePressAndHoldEnabled = false;
    };

    dock = {
      autohide = true;
      # Dissables automatically rearrange spaces based on most recent use
      mru-spaces = false;
      # Show recent applications in the dock.
      show-recents = false;
      # Size of the icons in the dock. The default is 64.
      tilesize = 30;
    };

    finder = {
      # Show full path in finder title
      _FXShowPosixPathInTitle = true;
      # Show file extension
      AppleShowAllExtensions = true;
      ShowPathbar = true;
    };

  };


  nixpkgs.hostPlatform = currentSystem;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
