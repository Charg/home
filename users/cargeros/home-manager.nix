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

{

  imports =
    [
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
  home.packages =
    [
      # Shared packages

      # CLI Tools
      pkgs.awscli2
      pkgs.bottom
      pkgs.dig
      pkgs.docker-compose
      pkgs.file
      # pkgs.ghostty
      pkgs.htop
      pkgs.jq
      pkgs.kubectl
      pkgs.kube-prompt
      pkgs.kubernetes-helm
      pkgs.lsof
      pkgs.minikube
      pkgs.nixfmt-rfc-style
      pkgs.nnn
      pkgs.nodejs
      pkgs.python313
      pkgs.ripgrep
      pkgs.sqlite
      pkgs.tmux
      pkgs.yubikey-manager
      pkgs.uv
      pkgs.zoxide

      # Network Tools
      # pkgs.cloudflare-warp # FIX: Flooding journal logs with weird GUI error
      pkgs.nmap
      pkgs.wireshark
    ];

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
