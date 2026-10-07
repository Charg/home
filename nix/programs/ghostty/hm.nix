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
      font-family = "JetBrains Mono";
      font-feature = [
        "-calt"
        "-liga"
        "-dlig"
      ];
      # Prevent Ghostty from drawing the cell-size overlay on layout updates
      resize-overlay = "never";
    };
  };
}
