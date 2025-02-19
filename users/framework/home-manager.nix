{ isWSL, inputs, ... }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux && !isWSL;
in
{

  #
  # Packages
  #
  home.packages =
    [
      # Shared packages

      # CLI Tools
      pkgs.awscli2
      pkgs.bottom
      pkgs.direnv
      pkgs.docker-compose
      pkgs.file
      pkgs.ghostty
      pkgs.htop
      pkgs.jq
      pkgs.kubectl
      pkgs.kubernetes-helm
      pkgs.lsof
      pkgs.minikube
      pkgs.nixfmt-rfc-style
      pkgs.python313
      pkgs.ripgrep
      pkgs.tmux
      pkgs.xclip # NOTE: Xorg clipboard. wclip or wl-copy if using wayland
      pkgs.yubikey-manager
      pkgs.zoxide

      # Network Tools
      # pkgs.cloudflare-warp # FIX: Flooding journal logs with weird GUI error
      pkgs.nmap
      pkgs.wireshark
    ]

    # Linux Packages
    ++ (lib.optionals isLinux [
      # Browsers
      pkgs.chromium

      # Desktop Apps
      pkgs.caffeine-ng
      pkgs.feh # image viewer
      pkgs.input-leap
      pkgs.pop-launcher
      pkgs.satty

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

  programs.firefox = {
    enable = isLinux;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    userEmail = "chris@syn.sh";
    userName = "chris";
    extraConfig.init.defaultBranch = "main";
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # TODO: Move this to ./apps/?
  programs.vscode = {
    enable = isLinux;
    extensions = with pkgs.vscode-extensions; [
      dracula-theme.theme-dracula
      github.copilot
      github.copilot-chat
      golang.go
      hashicorp.terraform
      oderwat.indent-rainbow
      jnoortheen.nix-ide
      mkhl.direnv
      ms-python.python
      ms-python.vscode-pylance
      ms-vscode-remote.remote-ssh
      redhat.vscode-yaml
      streetsidesoftware.code-spell-checker
      vscodevim.vim
    ];

    userSettings = {
      "[nix]"."editor.tabSize" = 2;
      "chat.commandCenter.enabled" = true;
      "editor.formatOnSave" = true;
      "editor.minimap.enabled" = false;
      "explorer.confirmDelete" = false;
      "files.insertFinalNewline" = true;
      "files.trimFinalNewlines" = true;
      "files.trimTrailingWhitespace" = true;
      "github.copilot.enable"."markdown" = "true";

      # telemetry
      "redhat.telemetry.enabled" = false;
      "telemetry.enableTelemetry" = false;
      "telemetry.telemetryLevel" = "off";
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.zsh.enable = true;

  programs.starship.enable = true;

  programs.tmux = {
    enable = true;
    aggressiveResize = true;
    keyMode = "vi";
    terminal = "screen-256color";
  };

  programs.ssh = {
    enable = true;
    controlMaster = "auto";
    controlPath = "~/.ssh/sockets/S.%r@%h:%p";
    controlPersist = "10m";
    addKeysToAgent = "yes";
    forwardAgent = false;
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/github";
        identitiesOnly = true;
      };
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];
  };

  #
  # Home config
  #

  home.shellAliases = {
    nrebuild = "sudo nixos-rebuild switch --flake .#framework13";
    ngarbage = "sudo nix-collect-garbage -d";
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    PAGER = "less -FirSwX";
  };

  home.file = {
    ".ssh/sockets/.keep".text = "# Managed by Home Manager";
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

  #
  # GNOME config
  #

  # TODO: Move this to gnome?
  dconf.settings = lib.mkIf isLinux {
    "gnome/desktop/peripherals/mouse" = {
      natural-scroll = false;
    };

    "gnome/desktop/peripherals/touchpad" = {
      natural-scroll = false;
    };

    "org/gnome/desktop/wm/keybindings" = {
      close = [
        "<Super>q"
        "<Alt>F4"
      ];
      minimize = [ "<Super>comma" ];
      toggle-maximized = [ "<Super>m" ];
      move-to-monitor-left = [ ];
      move-to-monitor-right = [ ];
      move-to-monitor-up = [ ];
      move-to-monitor-down = [ ];
      move-to-workspace-down = [ ];
      move-to-workspace-up = [ ];
      switch-to-workspace-down = [ "<Primary><Super>Down" ];
      switch-to-workspace-up = [ "<Primary><Super>Up" ];
      switch-to-workspace-left = [ ];
      switch-to-workspace-right = [ ];
      maximize = [ ];
      unmaximize = [ ];
      move-to-workspace-1 = [ "<Shift><Super>1" ];
      move-to-workspace-2 = [ "<Shift><Super>2" ];
      move-to-workspace-3 = [ "<Shift><Super>3" ];
      move-to-workspace-4 = [ "<Shift><Super>4" ];
      move-to-workspace-5 = [ "<Shift><Super>5" ];
      switch-to-workspace-1 = [ "<Super>1" ];
      switch-to-workspace-2 = [ "<Super>2" ];
      switch-to-workspace-3 = [ "<Super>3" ];
      switch-to-workspace-4 = [ "<Super>4" ];
      switch-to-workspace-5 = [ "<Super>5" ];
      switch-to-workspace-6 = [ "<Super>6" ];
      switch-to-workspace-7 = [ "<Super>7" ];
      switch-to-workspace-8 = [ "<Super>8" ];
    };

    "org/gnome/shell/keybindings" = {
      open-application-menu = [ ];
      switch-to-application-1 = [ ];
      switch-to-application-2 = [ ];
      switch-to-application-3 = [ ];
      switch-to-application-4 = [ ];
      switch-to-application-5 = [ ];
      toggle-message-tray = [ "<Super>v" ];
      toggle-overview = [ ];
    };

    "org/gnome/mutter/keybindings" = {
      toggle-tiled-left = [ ];
      toggle-tiled-right = [ ];
    };

    "org/gnome/mutter/wayland/keybindings" = {
      restore-shortcuts = [ ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      screensaver = [ "<Super>Escape" ];
      home = [ "<Super>f" ];
      www = [ "<Super>b" ];
      terminal = [ "<Super>t" ];
      email = [ "<Super>e" ];
      rotate-video-lock-static = [ ];
    };

    "org/gnome/shell/extensions/pop-shell" = {
      active-hint = false;
      focus-down = [
        "<Super>Down"
        "<Super>j"
      ];
      focus-left = [
        "<Super>Left"
        "<Super>h"
      ];
      focus-right = [
        "<Super>Right"
        "<Super>l"
      ];
      focus-up = [
        "<Super>Up"
        "<Super>k"
      ];
      pop-monitor-down = [ ];
      pop-monitor-left = [
        "<Shift><Super>Left"
        "<Shift><Super>h"
      ];
      pop-monitor-right = [
        "<Shift><Super>Right"
        "<Shift><Super>l"
      ];
      pop-monitor-up = [ ];
      pop-workspace-down = [
        "<Shift><Super>Down"
        "<Shift><Super>j"
      ];
      pop-workspace-up = [
        "<Shift><Super>Up"
        "<Shift><Super>k"
      ];
      tile-accept = [ "Return" ];
      tile-by-default = true;
      tile-enter = [ "<Super>Return" ];
      tile-reject = [ "Escape" ];
      toggle-floating = [ "<Super>g" ];
      toggle-stacking-global = [ "<Super>s" ];
      toggle-tiling = [ "<Super>y" ];
    };

    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        pkgs.gnomeExtensions.space-bar.extensionUuid
        pkgs.gnomeExtensions.clipboard-history.extensionUuid
        pkgs.gnomeExtensions.pop-shell.extensionUuid
        pkgs.gnomeExtensions.user-themes.extensionUuid
      ];
      disabled-extensions = [ ];
    };

    "org/gnome/desktop/wm/preferences" = {
      audible-bell = false;
      num-workspaces = 8;
    };

    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      # font-antialiasing = "rgba";
      # font-hinting = "full";
      # gtk-enable-primary-paste = true;
      # # TODO: might not be needed with Stylix
      # gtk-theme = "Adwaita"; # breaks stylix on build
      # icon-theme = "Adwaita";
      # cursor-theme = "Adwaita";
    };
  };

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.11";
}
