{ pkgs, ... }:
let
  gnomeExtensionVicinae = pkgs.callPackage ../packages/gnome-shell-extension-vicinae.nix { };
in
{

  #
  # GNOME
  #
  services.udev.packages = [ pkgs.gnome-settings-daemon ];
  services.gnome = {
    gcr-ssh-agent.enable = false;
  };

  # Kill the heaviest cgroup in a user's session under sustained memory
  # pressure, instead of letting the desktop thrash until it locks up.
  systemd.oomd.enableUserSlices = true;

  services.desktopManager.gnome.enable = true;
  # Unwrapped GTK3/Qt apps (e.g. VirtualBox) abort when opening a file dialog
  # because the session only ships GTK4's schemas, not org.gtk.Settings.FileChooser.
  services.desktopManager.gnome.extraGSettingsOverridePackages = [ pkgs.gtk3 ];
  services.displayManager.gdm.enable = true;

  # pop-shell's floating_exceptions/main.js is a standalone GTK3 GJS app,
  # but the GNOME session is GTK4-based and doesn't export a GTK3 typelib.
  environment.variables.GI_TYPELIB_PATH = "${pkgs.gtk3}/lib/girepository-1.0";

  environment.gnome.excludePackages = with pkgs; [
    atomix # puzzle game
    baobab # disk usage analyzer
    cheese # webcam tool
    epiphany # web browser
    evince # document viewer
    geary # email reader
    gedit
    gnome-calendar
    gnome-characters
    gnome-clocks
    gnome-console
    gnome-contacts
    gnome-disk-utility
    gnome-font-viewer
    gnome-logs
    gnome-maps
    gnome-music
    gnome-photos
    gnome-system-monitor
    gnome-terminal
    gnome-tour
    gnome-weather
    hitori # sudoku game
    iagno # go game
    simple-scan
    snapshot
    tali # poker game
    yelp # help viewer
  ];

  # List of Gnome specific packages
  environment.systemPackages = with pkgs; [
    dconf2nix
    # appindicator spawns `gjs` from PATH to find existing tray icons.
    gjs
    gnomeExtensions.appindicator
    gnomeExtensions.clipboard-history
    gnomeExtensions.pop-shell # https://github.com/pop-os/shell
    gnomeExtensions.space-bar
    gnomeExtensions.tray-icons-reloaded
    gnomeExtensions.user-themes
    gnome-tweaks
    xclip
    gnomeExtensionVicinae
  ];

}
