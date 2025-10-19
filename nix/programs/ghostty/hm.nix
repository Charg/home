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
      mouse-hide-while-typing = true;
    };
  };
}
