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
    ../../programs/ghostty/hm.nix
    ../../programs/git/hm.nix
    ../../programs/neovim/hm.nix
    ../../programs/ssh/hm.nix
    ../../programs/starship/hm.nix
    ../../programs/tmux/hm.nix
    (import ../../programs/vicinae/hm.nix { inherit inputs; })
    ../../programs/vscode/hm.nix
    ../../programs/zoxide/hm.nix
    ../../programs/zsh/hm.nix
  ]
  ++ lib.optionals isLinux [
    ../../programs/gnome/hm.nix # TODO: check if we are even using gnome
  ];

  #
  # Packages
  #
  home.packages =
    commonPkgs

    # Linux Packages
    ++ (lib.optionals isLinux [
      # Browsers
      pkgs.chromium

      # Desktop Apps
      pkgs.caffeine-ng
      pkgs.calibre
      pkgs.darktable # image editing
      pkgs.feh # image viewer
      pkgs.satty
      pkgs.synology-drive-client
      pkgs.vlc
      pkgs.kooha # screen recorder

      # Productivity
      pkgs.deskflow # mouse/keyboard sharing

      # Electron Apps
      pkgs.anytype
      pkgs.bitwarden-desktop
      pkgs.discord
      pkgs.signal-desktop
      pkgs.slack
      pkgs.spotify

      # Framework
      pkgs.framework-tool # https://github.com/FrameworkComputer/framework-system

      # Network Tools
      # pkgs.cloudflare-warp # FIX: Flooding journal logs with weird GUI error

      # Misc
      pkgs.wl-clipboard
    ])

    # WSL Packages
    ++ (lib.optionals isWSL [
      pkgs.wslu
      pkgs.xclip
    ]);

  #
  # Program config
  #
  programs.bat.enable = true;
  programs.firefox.enable = isLinux;

  #
  # Services
  #
  services.flameshot = {
    enable = true;
    package = pkgs.flameshot.override { enableWlrSupport = true; };
  };

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

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "firefox.desktop" ];
      "text/xml" = [ "firefox.desktop" ];
      "application/xhtml+xml" = [ "firefox.desktop" ];
      "application/vnd.mozilla.xul+xml" = [ "firefox.desktop" ];
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
      "x-scheme-handler/ftp" = [ "firefox.desktop" ];
    };
  };

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.11";
}
