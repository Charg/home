{ pkgs, ... }:

{
  programs.home-manager.enable = true;

  # gh extensions, linked the way programs.gh.extensions does it, without
  # letting home-manager take over ~/.config/gh/config.yml.
  xdg.dataFile."gh/extensions/gh-actions-lock/gh-actions-lock".source =
    "${pkgs.gh-actions-lock}/bin/gh-actions-lock";
}
