{ inputs, pkgs, ... }:

{
  # Using determinate to manage nix. Not nix-darwin.
  nix.enable = false;

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "uninstall";
      upgrade = true;
    };
    brews = [
      "jfrog-cli"
      "podman-compose"
      "podman"
    ];
    caskArgs = {
      appdir = "~/Applications";
      require_sha = true;
    };
    casks  = [
      "amethyst"
      "deskflow"
      "elgato-wave-link"
      "firefox"
      "flameshot"
      "ghostty"
      "google-chrome"
      "intellij-idea-ce"
      "podman-desktop"
      "raycast"
      "secretive"
      "slack"
      "vagrant"
      "virtualbox"
      "zoom"
      "zulu@17"
    ];
    taps = [
      "deskflow/homebrew-tap"
    ];
  };

  # The user should already exist, but we need to set this up so Nix knows
  # what our home directory is (https://github.com/LnL7/nix-darwin/issues/423).
  users.users.cargeros = {
    home = "/Users/cargeros";
  };

  # Required for some settings like homebrew to know what user to apply to.
  system.primaryUser = "cargeros";
}
