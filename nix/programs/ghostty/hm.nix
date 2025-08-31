{
  config,
  pkgs,
  lib,
  currentSystemName,
  ...
}:

{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      clipboard-read = "allow";
      clipboard-write = "allow";
      copy-on-select = "clipboard";
      mouse-hide-while-typing = true;
    };
  };
}
