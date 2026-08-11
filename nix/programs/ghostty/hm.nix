{
  isDarwin,
  config,
  pkgs,
  lib,
  currentSystemName,
  ...
}:

{
  programs.ghostty = {
    enable = true;
    package = lib.mkIf isDarwin null;
    enableZshIntegration = true;
    settings = {
      clipboard-read = "allow";
      clipboard-write = "allow";
      copy-on-select = "clipboard";
      desktop-notifications = true;
      mouse-hide-while-typing = true;
      font-feature = [
        "-calt"
        "-liga"
        "-dlig"
      ];
      # MacOs Only
      window-step-resize = false;
      window-padding-balance = false;
      # Disable GTK Client-Side Decorations (Essential for Tiling WMs)
      window-decoration = false;
      # Prevent Ghostty from drawing the cell-size overlay on layout updates
      resize-overlay = "never";
    };
  };
}
