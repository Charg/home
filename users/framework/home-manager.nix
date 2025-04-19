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
      pkgs.python313
      pkgs.ripgrep
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

      # Desktop Apps
      pkgs.caffeine-ng
      pkgs.calibre
      pkgs.feh # image viewer
      pkgs.flameshot # screenshots
      pkgs.input-leap
      pkgs.pop-launcher
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

  programs.direnv = {
    enable = true;
    enableZshIntegration = true; # see note on other shells below
    nix-direnv.enable = true;
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
    git = true;
  };

  programs.firefox = {
    enable = isLinux;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.git = {
    enable = true;
    delta.enable = true;
    lfs.enable = true;
    userEmail = "chris@syn.sh";
    userName = "chris";

    aliases = {
      a = "add -p";
      ch = "diff --cached";
      fixup = "commit --amend -C HEAD";
      fpush = "push --force-with-lease";
      lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      pr = "!f(){ gh pr view --web; }; f";
      pushb = "!f(){ BRANCH=$(git symbolic-ref --short HEAD); git push --set-upstream origin $BRANCH;}; f";
      root = "rev-parse --show-toplevel";
    };

    ignores = [
      "**/modules/*/.terraform.lock.hcl"
      ".DS_Store"
      ".venv"
      "venv"
    ];

    extraConfig = {
      color.ui = "auto";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      aws.disabled = false;
      battery.disabled = false;
      direnv.disabled = false;
      terraform.disabled = false;

      kubernetes.disabled = false;
      kubernetes = {
        contexts = [
          { context_pattern = "prod"; style = "red"; }
        ];
      };

      # Dracula Theme https://draculatheme.com/starship
      aws.style = "bold #ffb86c";
      cmd_duration.style = "bold #f1fa8c";
      directory.style = "bold #50fa7b";
      hostname.style = "bold #ff5555";
      git_branch.style = "bold #ff79c6";
      git_status.style = "bold #ff5555";
      username = {
        format = "[$user]($style) on ";
        style_user = "bold #bd93f9";
      };
      character = {
        success_symbol = "[λ](bold #f8f8f2)";
        error_symbol = "[λ](bold #ff5555)";
      };



    };
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

  # TODO: Move this to ../../programs/zsh
  programs.zsh = {
    enable = true;
    autocd = true;
    autosuggestion.enable = true;

    dirHashes = {
      code  = "$HOME/code";
      docs  = "$HOME/Documents";
      down  = "$HOME/Downloads";
      home  = "$HOME/code/home";
    };

    history = {
      append = true;
      extended = true;
      size = 99999;
    };

    initExtra = ''
      . $HOME/.zsh_functions
    '';

    antidote = {
      enable = true;
      plugins = [
        "ohmyzsh/ohmyzsh"
	"ohmyzsh/ohmyzsh path:lib/clipboard.zsh"
        "ohmyzsh/ohmyzsh path:lib/git.zsh"
	"ohmyzsh/ohmyzsh path:plugins/aliases"
	"ohmyzsh/ohmyzsh path:plugins/extract"
	"ohmyzsh/ohmyzsh path:plugins/git"
	"ohmyzsh/ohmyzsh path:plugins/git-extras"
	"ohmyzsh/ohmyzsh path:plugins/kubectl"
	"ohmyzsh/ohmyzsh path:plugins/magic-enter"
	"ohmyzsh/ohmyzsh path:plugins/uv"
      ];
    };

    shellAliases = {
      _ = "sudo";
      a = "ansible";
      ap = "ansible-playbook";
      cat = "bat";
      g = "git";
      h = "helm";
      get_ip = "curl https://icanhazip.com";
      k = "kubectl";
      kp = "kube-prompt";
      l = "eza -l --tree --level=1";
      ls = "eza --tree --level=1";
      n = "nnn -deHiUx";
      v = "nvim";

      # git overrides
      gch = "git ch";
      gcm = "git commit --message";
      gia = "git add -p";
      gpb = "git pushb";
      gs = "git status";
      gtr = "cd $(git rev-parse --show-cdup)";

      # nix
      nixg = "sudo nix-collect-garbage -d";
      # TODO: Replace framework13 with the system name
      nixrs = "sudo nixos-rebuild switch --flake ~/code/home#framework13";
      nixrt = "sudo nixos-rebuild test --flake ~/code/home#framework13";
      nixfc = "nix flake check ~/code/home";
    };
  };

  programs.tmux = {
    enable = true;
    aggressiveResize = true;
    historyLimit = 500000;
    keyMode = "vi";
    shortcut = "a";
    terminal = "screen-256color";
    plugins = with pkgs; [
      tmuxPlugins.sensible
    ];
    extraConfig = ''
      set -g base-index 1
      set -g pane-base-index 1

      set -g status-keys vi
      set -g renumber-windows on	      # auto renumber windows when a window is closed
      set -sg escape-time 10                  # Set the escape-time to 10ms. Allows quick escapes when using vim in tmux
      setw -g mode-keys vi
      setw -g mouse on
      setw -g monitor-activity on
      set-window-option -g allow-rename off   # Dont auto rename window sessions after a command is run
      set-option -g visual-activity on        # Enable window notifications

      # remove key bindings
      unbind %      # Split screen
      unbind ,      # Name a window
      unbind .      # Move current window to index
      unbind n      # Next window
      unbind p      # Previous window
      unbind [      # Enter copy mode
      unbind l      # Move to the previously selected window

      # keybindings
      bind-key -T copy-mode-vi v send-keys -X begin-selection	               # VI like copy experience
      bind-key -T copy-mode-vi y send-keys -X copy-selection 	               # VI like copy experience
      bind-key a      send-prefix			                       # Send prefix through to terminal
      bind-key |      split-window -h			                       # Horizontal Split
      bind-key \      split-window -h			                       # Horizontal Split - Easier to type
      bind-key -      split-window -v			                       # Vertical Split
      bind-key space  next-layout
      bind-key x      kill-pane                                                # Kill the current pane
      bind-key X      kill-window                                              # Kill entire window - all panes
      bind-key q      confirm-before kill-session                              # Quit safely. Kills current session
      bind-key Q      confirm-before kill-server                               # Quit safely. Kills all sessions
      bind-key <      swap-window -t :-                                        # Move window to the right
      bind-key >      swap-window -t :+                                        # Move window to the left
      bind-key n      command-prompt "rename-window %%"                        # Rename window
      bind-key N      command-prompt "rename-session %%"                       # Rename session
      bind-key Escape copy-mode -u                                             # Enter copy mode
      bind-key Up     copy-mode -u					       # Enter copy mode
      bind-key C-h    resize-pane -L 10                                        # Resize pane to the right 10 cells
      bind-key C-l    resize-pane -R 10                                        # Resize pane to the left 10 cells
      bind-key C-j    resize-pane -D 10                                        # Resize pane to down 10 cells
      bind-key C-k    resize-pane -U 10                                        # Resize pane to up 10 cells
      bind-key C-c    run -b "tmux save-buffer - | xclip -i -sel clipboard*"   # Copy current buffer to clibboard
      bind-key -n M-1 select-window -t 1                                       # switch windows using alt+number
      bind-key -n M-2 select-window -t 2                                       # switch windows using alt+number
      bind-key -n M-3 select-window -t 3                                       # switch windows using alt+number
      bind-key -n M-4 select-window -t 4                                       # switch windows using alt+number
      bind-key -n M-5 select-window -t 5                                       # switch windows using alt+number
      bind-key -n M-6 select-window -t 6                                       # switch windows using alt+number
      bind-key -n M-7 select-window -t 7                                       # switch windows using alt+number
      bind-key -n M-8 select-window -t 8                                       # switch windows using alt+number
      bind-key -n M-9 select-window -t 9                                       # switch windows using alt+number
    '';
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

  home.sessionVariables = {
    EDITOR = "nvim";
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

  #
  # GNOME config
  #

  # TODO: should check if we are using gnome...
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
