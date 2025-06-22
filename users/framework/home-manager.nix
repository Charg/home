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

  imports = [
    ../../programs/direnv/hm.nix
    ../../programs/eza/hm.nix
    ../../programs/fzf/hm.nix
    ../../programs/git/hm.nix
    ../../programs/gnome/hm.nix # TODO: check if we are even using gnome. currently wrapped in a lib.mkfif isLinux
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
      pkgs.ghostty
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
      pkgs.xclip # NOTE: Xorg clipboard. wclip or wl-copy if using wayland
      pkgs.yubikey-manager
      pkgs.uv
      pkgs.zoxide

      # Network Tools
      pkgs.cloudflare-warp # FIX: Flooding journal logs with weird GUI error
      pkgs.nmap
      pkgs.wireshark
    ]

    # Linux Packages
    ++ (lib.optionals isLinux [
      # Browsers
      pkgs.chromium

      # gnome/GTK
      pkgs.gnome-themes-extra
      pkgs.pop-gtk-theme
      pkgs.pop-icon-theme
      pkgs.pop-launcher

      # Fonts
      pkgs.adwaita-icon-theme

      # Desktop Apps
      pkgs.caffeine-ng
      pkgs.calibre
      pkgs.darktable # image editing
      pkgs.feh # image viewer
      pkgs.flameshot # screenshots
      # pkgs.input-leap
      pkgs.satty
      pkgs.synology-drive-client
      pkgs.vlc

      # Electron Apps
      pkgs.anytype
      pkgs.bitwarden-desktop
      pkgs.discord
      pkgs.signal-desktop
      pkgs.slack
      pkgs.spotify

      # Development
      pkgs.vscode

      # Framework
      pkgs.framework-tool # https://github.com/FrameworkComputer/framework-system
    ])

    # WSL Packages
    ++ (lib.optionals isWSL [
      pkgs.wslu
    ]);

  #
  # Program config
  #
  programs.bat.enable = true;
  programs.firefox.enable = isLinux;

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

  home.file = {
    ".ssh/sockets/.keep".text = "# Managed by Home Manager";
    ".zsh_functions".source = ../../programs/zsh/functions;

    ".direnvrc".text = ''
      layout_uv() {
        watch_file .python-version pyproject.toml uv.lock
        uv sync --frozen || true
        venv_path="$(expand_path "''${UV_PROJECT_ENVIRONMENT:-.venv}")"
        if [[ -e $venv_path ]]; then
            VIRTUAL_ENV="$(pwd)/.venv"
            PATH_add "$VIRTUAL_ENV/bin"
            export UV_ACTIVE=1  # or VENV_ACTIVE=1
            export VIRTUAL_ENV
        fi
        if [[ ! -e $venv_path ]]; then
            log_status "No virtual environment exists. Executing \`uv venv\` to create one."
        fi
      }
    '';

    # TODO: mkif isLinux
    ".config/pop-shell/config.json".text = ''
      {
        "float": [
          {
            "class": "pop-shell-example",
            "title": "pop-shell-example"
          },
          {
            "class": "firefox",
            "title": "^(?!.*Mozilla Firefox).*$",
            "disabled": true
          },
          {
            "class": "zoom",
            "disabled": true
          },
          {
            "class": "Slack",
            "disabled": true
          },
        ],
        "skiptaskbarhidden": [],
        "log_on_focus": false
      }
    '';
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
