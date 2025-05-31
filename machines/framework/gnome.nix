{ pkgs, ... }:
{

  #
  # GNOME
  #
  services.udev.packages = [ pkgs.gnome-settings-daemon ];
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true; # Enable GNOME DE
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
    gnomeExtensions.appindicator
    gnomeExtensions.clipboard-history
    gnomeExtensions.pop-shell # https://github.com/pop-os/shell
    gnomeExtensions.space-bar
    gnomeExtensions.tray-icons-reloaded
    gnomeExtensions.user-themes
    gnome-tweaks
    xclip
  ];

}
