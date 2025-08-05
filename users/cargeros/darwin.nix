{ inputs, pkgs, ... }:

{
  # Using determinate to manage nix. Not nix-darwin.
  nix.enable = false;

  homebrew = {
    enable = true;
    casks  = [
      "amethyst"
      "bitwarden"
      "firefox"
      "flameshot"
      "ghostty"
      "google-chrome"
      "podman-desktop"
      "raycast"
      "slack"
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
