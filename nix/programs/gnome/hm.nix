{
  isLinux,
  lib,
  pkgs,
  ...
}:

let
  # for whatever reason, we need to create a shell script for this to work as a shortcut
  # https://github.com/flameshot-org/flameshot/issues/3326#issuecomment-1788440850
  flameshot-gui = pkgs.writeShellScriptBin "flameshot-gui" "${pkgs.flameshot}/bin/flameshot gui";
in

{
  home.packages = [
    pkgs.gnome-themes-extra
    pkgs.pop-gtk-theme
    pkgs.pop-icon-theme

    # Fonts
    pkgs.adwaita-icon-theme
  ];

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
      maximize = [ ];
      minimize = [ "<Super>comma" ];
      move-to-monitor-down = [ ];
      move-to-monitor-left = [ ];
      move-to-monitor-right = [ ];
      move-to-monitor-up = [ ];
      move-to-workspace-1 = [ "<Shift><Super>1" ];
      move-to-workspace-2 = [ "<Shift><Super>2" ];
      move-to-workspace-3 = [ "<Shift><Super>3" ];
      move-to-workspace-4 = [ "<Shift><Super>4" ];
      move-to-workspace-5 = [ "<Shift><Super>5" ];
      move-to-workspace-down = [ ];
      move-to-workspace-up = [ ];
      switch-to-workspace-1 = [ "<Super>1" ];
      switch-to-workspace-2 = [ "<Super>2" ];
      switch-to-workspace-3 = [ "<Super>3" ];
      switch-to-workspace-4 = [ "<Super>4" ];
      switch-to-workspace-5 = [ "<Super>5" ];
      switch-to-workspace-6 = [ "<Super>6" ];
      switch-to-workspace-7 = [ "<Super>7" ];
      switch-to-workspace-8 = [ "<Super>8" ];
      switch-to-workspace-down = [ "<Primary><Super>Down" ];
      switch-to-workspace-left = [ ];
      switch-to-workspace-right = [ ];
      switch-to-workspace-up = [ "<Primary><Super>Up" ];
      toggle-maximized = [ "<Super>m" ];
      unmaximize = [ ];
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

      # disable screenshot interface. replace with flameshot
      show-screenshot-ui = [ ];
    };

    "org/gnome/mutter".dynamic-workspaces = false;

    "org/gnome/mutter/keybindings" = {
      toggle-tiled-left = [ ];
      toggle-tiled-right = [ ];
    };

    "org/gnome/mutter/wayland/keybindings" = {
      restore-shortcuts = [ ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      screensaver = [ "<Super>l" ];
      home = [ "<Super>f" ];
      www = [ "<Super>b" ];
      email = [ "<Super>e" ];

      # Terminal
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ghost/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot" = {
      binding = "<control>Print";
      # command="${pkgs.flameshot}/bin/flameshot gui";
      command = "${flameshot-gui}/bin/flameshot-gui";
      name = "flameshot";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ghost" = {
      binding = "<Super>t";
      command = "ghostty";
      name = "Launch terminal";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae" = {
      binding = "<Alt><Super>space";
      command = "vicinae";
      name = "Launch Vicinae";
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
        pkgs.gnomeExtensions.appindicator.extensionUuid
        pkgs.gnomeExtensions.clipboard-history.extensionUuid
        pkgs.gnomeExtensions.pop-shell.extensionUuid
        pkgs.gnomeExtensions.space-bar.extensionUuid
        pkgs.gnomeExtensions.tray-icons-reloaded.extensionUuid
        pkgs.gnomeExtensions.user-themes.extensionUuid
        "vicinae@dagimg-dot"
      ];
      disabled-extensions = [ ];
    };

    "org/gnome/shell/extensions/user-theme".name = "Pop-dark";

    "org/gnome/desktop/wm/preferences" = {
      audible-bell = false;
      # org/gnome/mutter/dynamic-workspaces must be false
      # otherwise num-workspaces isn't static
      num-workspaces = 8;
    };

    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      cursor-theme = "Pop";
      font-antialiasing = "rgba";
      font-hinting = "slight";
      gtk-theme = "Pop-dark";
      icon-theme = "Pop";
    };
  };

  # pop-shell configuration
  home.file.".config/pop-shell/config.json".text = ''
    {
      "float": [
        {
          "class": "firefox",
          "title": "^(?!.*Mozilla Firefox).*$",
          "disabled": true
        },
        {
          "class": "Slack",
          "disabled": true
        },
        {
          "class": "zoom",
        },
        {
          "class": "vicinae",
          "title": ".*vicinae.*",
        },
      ],
      "skiptaskbarhidden": [],
      "log_on_focus": false
    }
  '';
}
