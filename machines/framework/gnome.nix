{pkgs, ...}: {

  #
  # GNOME
  #
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true; # Enable GNOME DE
  environment.gnome.excludePackages = with pkgs; [
    gedit
    gnome-console
    gnome-photos
    gnome-tour
    snapshot
    atomix # puzzle game
    baobab # disk usage analyzer
    cheese # webcam tool
    epiphany # web browser
    evince # document viewer
    geary # email reader
    gnome-calendar
    gnome-characters
    gnome-clocks
    gnome-contacts
    gnome-disk-utility
    gnome-font-viewer
    gnome-logs
    gnome-maps
    gnome-music
    gnome-system-monitor
    gnome-terminal
    gnome-weather
    hitori # sudoku game
    iagno # go game
    simple-scan
    tali # poker game
    yelp # help viewer
  ];

  # List of Gnome specific packages
  environment.systemPackages = with pkgs; [
    dconf2nix
    gnomeExtensions.clipboard-history
    gnomeExtensions.pop-shell # https://github.com/pop-os/shell
    gnomeExtensions.space-bar
    gnomeExtensions.user-themes
    gnome-tweaks
    xclip
  ];

}
