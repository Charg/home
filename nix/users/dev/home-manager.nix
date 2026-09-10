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
  commonPkgs = import ../../common/hm-common-pkgs.nix { inherit pkgs inputs; };
in

{
  imports = [
    ../../common/hm-common.nix
    ../../common/scripts/hm.nix
    ../../programs/agent-orchestrator/hm.nix
    ../../programs/claude-code/hm.nix
    ../../programs/delta/hm.nix
    ../../programs/direnv/hm.nix
    ../../programs/eza/hm.nix
    ../../programs/fzf/hm.nix
    ../../programs/git/hm.nix
    ../../programs/gpg/hm.nix
    ../../programs/herdr/hm.nix
    ../../programs/neovim/hm.nix
    ../../programs/opencode/hm.nix
    ../../programs/orca/hm.nix
    ../../programs/podman/hm.nix
    ../../programs/ripgrep/hm.nix
    ../../programs/ssh/hm.nix
    ../../programs/starship/hm.nix
    ../../programs/tmux/hm.nix
    ../../programs/zoxide/hm.nix
    ../../programs/zsh/hm.nix
  ];

  home.packages = commonPkgs;

  programs.bat.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    PAGER = "less -FirSwX";

    # Lets `nh os switch` / `nh home switch` run without a flake path argument
    NH_FLAKE = "${config.home.homeDirectory}/code/home";

    # Needs to be set before antidote installs the magic-enter plugin
    MAGIC_ENTER_GIT_COMMAND = "git status -u";
  };

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "25.11";
}
