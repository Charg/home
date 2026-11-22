# macOS machines managed with nix-darwin. Nix itself is installed and managed
# by Determinate, not nix-darwin.
{
  config,
  pkgs,
  host,
  ...
}:
{
  nix.enable = false;

  environment.systemPackages = [ pkgs.vim ];
  nixpkgs.hostPlatform = host.system;

  # The user already exists; declaring the home lets nix-darwin and Home
  # Manager find it (https://github.com/LnL7/nix-darwin/issues/423).
  users.users.${host.user} = {
    home = "/Users/${host.user}";
  };
  # Settings such as homebrew apply to this user.
  system.primaryUser = host.user;

  time.timeZone = "America/Los_Angeles";

  programs.zsh.enable = true;

  services.openssh.enable = true;

  # Ghostty comes from a homebrew cask; point ncurses at its bundled terminfo.
  environment.variables.TERMINFO_DIRS = [
    "${config.users.users.${host.user}.home}/Applications/Ghostty.app/Contents/Resources/terminfo"
    "/Applications/Ghostty.app/Contents/Resources/terminfo"
  ];

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
}
