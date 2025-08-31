{
  config,
  lib,
  pkgs,
  inputs,
  currentSystemName,
  isDarwin,
  isLinux,
  isWSL,
  ...
}:

let
  commonPkgs = import ../../common/hm-common-pkgs.nix { inherit pkgs; };
in

{

  imports = [
      ../../programs/direnv/hm.nix
      ../../programs/eza/hm.nix
      ../../programs/fzf/hm.nix
      ../../programs/git/hm.nix
      ../../programs/neovim/hm.nix
      ../../programs/ssh/hm.nix
      ../../programs/starship/hm.nix
      ../../programs/tmux/hm.nix
      ../../programs/vscode/hm.nix
      ../../programs/zoxide/hm.nix
      ../../programs/zsh/hm.nix
  ];

  #
  # Packages
  #
  home.packages = commonPkgs;

  #
  # Program config
  #
  programs.bat.enable = true;
  programs.firefox.enable = true;

  #
  # Home config
  #

  home.sessionVariables = {
    EDITOR = "vim";
    VISUAL = "vim";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    PAGER = "less -FirSwX";

    # Needs to be set before antidote installs the magic-enter plugin
    MAGIC_ENTER_GIT_COMMAND = "git status -u";
  };

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "25.05";
}
