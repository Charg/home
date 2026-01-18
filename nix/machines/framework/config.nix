{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./gnome.nix
  ];

  #
  # Bootloader
  #
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # resolves an issues with virtualbox 6.12. https://github.com/NixOS/nixpkgs/issues/363887#issuecomment-2536693220
  boot.kernelParams = [ "kvm.enable_virt_at_load=0" ];

  #
  # Networking
  #
  networking.networkmanager.enable = true; # Enable networking
  networking.hostName = "framework13";
  networking.wireguard.enable = true;

  networking.firewall.allowedTCPPorts = [ 
    24800 # DeskFlow
  ];

  networking.firewall.allowedUDPPorts = [ 
    24800 # DeskFlow
    51820 # WireGuard
  ];

  #
  # Hardware
  #
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported
        # Bluetooth adapters. Defaults to 'false'.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption. Defaults to
        # 'false'.
        FastConnectable = true;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = true;
      };
    };
  };




  #
  # System
  #
  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalization properties.
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

  virtualisation.docker.enable = true;
  virtualisation = {
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      # dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;

  security.sudo.wheelNeedsPassword = false;
  # Pipewire - allows to use the realtime scheduler for increased performance.
  security.rtkit.enable = true;

  # Smart Card Reader Service
  # Used for YubiKey related operations.
  services.pcscd.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    pulse.enable = true;

    wireplumber.extraConfig = {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        "bluez5.roles" = [
          "hsp_hs"
          "hsp_ag"
          "hfp_hf"
          "hfp_ag"
        ];
        # aptX HD causes problems with Sonos Ace
        "bluez5.codecs" = [
          "sbc"
          "sbc_xq"
          "aac"
          "ldac"
          "aptx"
          "aptx_ll"
          "aptx_ll_duplex"
          "lc3"
          "lc3plus_h3"
        ];
      };
    };
  };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  services.xserver = {
    enable = true;
    excludePackages = with pkgs; [ xterm ];
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
    settings = {
      PasswordAuthentication = false;
    };
  };

  # A simple daemon allowing you to update some devices' firmware
  # https://github.com/fwup-home/fwup
  # https://nixos.wiki/wiki/Fwupd
  services.fwupd.enable = true;

  # Enable power-profiles-daemon, a DBus daemon
  # Recommended at https://wiki.nixos.org/wiki/Hardware/Framework/Laptop_13
  services.power-profiles-daemon.enable = true;

  services.cloudflare-warp = {
    enable = true;
  };

  nix = {
    # package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).

  system.stateVersion = "24.11";
}
