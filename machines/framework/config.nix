{ config, pkgs, inputs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
      ./gnome.nix
    ];

  #
  # Bootloader
  #
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  #
  # Networking
  #
  networking.networkmanager.enable = true; # Enable networking
  networking.hostName = "framework13";

  #
  # System
  #
  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };


  # Define a user account. Don't forget to set a password with ‘passwd’.
  #users.users.framework = {
  #  description = "framework";
  #  extraGroups = [ "networkmanager" "wheel" "docker" ];
  #  isNormalUser = true;
  #  shell = pkgs.zsh;
  #};

  # TODO: Move to home manager
  # programs.firefox.enable = true;

  # TODO: Move to home manager
  # environment.systemPackages = with pkgs; [
  #   # Browsers
  #   firefox
  #   chromium

  #   # Desktop Apps
  #   caffeine-ng
  #   feh # image viewer
  #   input-leap
  #   pop-launcher
  #   satty

  #   # CLI Tools
  #   awscli2
  #   bottom
  #   docker-compose
  #   file
  #   ghostty
  #   htop
  #   jq
  #   kubectl
  #   kubernetes-helm
  #   lsof
  #   minikube
  #   ripgrep
  #   tmux
  #   xclip # NOTE: Xorg clipboard. wclip or wl-copy if using wayland
  #   yubikey-manager
  #   zoxide

  #   # Network Tools
  #   cloudflare-warp
  #   nmap
  #   wireshark

  #   # Electron Apps
  #   anytype
  #   bitwarden-desktop
  #   discord
  #   signal-desktop
  #   slack
  #   spotify

  #   # Development
  #   direnv
  #   git
  #   python313
  #   vscode

  #   # Framework
  #   framework-tool # https://github.com/FrameworkComputer/framework-system
  # ];

  virtualisation.docker.enable = true;

  security.sudo.wheelNeedsPassword = false;
  security.rtkit.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  services.xserver = {
    enable = true;
    excludePackages = with pkgs; [xterm];
    # Configure keymap in X11
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = false;

  # List services that you want to enable:
  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = { PasswordAuthentication = false; };
  };

  # A simple daemon allowing you to update some devices' firmware
  # https://github.com/fwup-home/fwup
  # https://nixos.wiki/wiki/Fwupd
  services.fwupd.enable = true;

  # Enable power-profiles-daemon, a DBus daemon
  # Recommended at https://wiki.nixos.org/wiki/Hardware/Framework/Laptop_13
  services.power-profiles-daemon.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).

  system.stateVersion = "24.11";
}

