{
  config,
  lib,
  pkgs,
  currentSystemUser,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../common/fonts.nix
    ../../common/gnome.nix
    ../../common/nix-ld.nix
    ../../common/system-packages.nix
  ];

  home-manager.users.${currentSystemUser}.imports = [ ./hm.nix ];

  #
  # Bootloader
  #
  # NixOS has its own ESP; Windows keeps its original one. Pick Windows from the
  # firmware boot menu.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  #
  # Disks
  #
  # Partitioned by hand next to Windows, so referenced by GPT
  # partition label rather than managed by disko.
  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-partlabel/nixos-root";
    allowDiscards = true;
    bypassWorkqueues = true;
  };

  fileSystems =
    lib.genAttrs [ "/" "/home" "/nix" ] (mount: {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [
        "subvol=${if mount == "/" then "root" else lib.removePrefix "/" mount}"
        "compress=zstd"
        "noatime"
      ];
    })
    // {
      "/boot" = {
        device = "/dev/disk/by-partlabel/nixos-esp";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };
    }
    # Windows NTFS volumes, via the in-kernel ntfs3 driver. Mounted on first
    # access so a missing/dirty volume never blocks boot. If Windows Fast
    # Startup is ever re-enabled, ntfs3 will refuse these read-write.
    //
      lib.mapAttrs
        (_: uuid: {
          device = "/dev/disk/by-uuid/${uuid}";
          fsType = "ntfs3";
          options = [
            "uid=1000"
            "gid=100"
            "umask=022"
            "noatime"
            "windows_names"
            "nofail"
            "noauto"
            "x-systemd.automount"
            "x-systemd.idle-timeout=10min"
            "x-gvfs-show"
          ];
        })
        {
          "/mnt/windows" = "CE8EE5AA8EE58AF3"; # C: (nvme0n1p3)
          "/mnt/extras" = "521A02351A02169F"; # "Extras" (nvme1n1p2)
        };

  services.btrfs.autoScrub.enable = true;

  zramSwap.enable = true;

  #
  # Networking
  #
  networking.networkmanager.enable = true;
  networking.hostName = "tortuga";

  systemd.services.NetworkManager-wait-online.enable = false;

  networking.networkmanager.unmanaged = [
    "interface-name:docker*"
    "interface-name:br-*"
    "interface-name:veth*"
  ];

  #
  # Graphics
  #
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    # Open kernel modules need Turing (RTX 20xx / GTX 16xx) or newer.
    open = true;
    # Saves VRAM across suspend; avoids corrupted desktop on resume.
    powerManagement.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  #
  # System
  #
  time.timeZone = "America/Los_Angeles";
  # Windows keeps the RTC in local time; match it so the clock doesn't jump
  # when switching OSes.
  time.hardwareClockInLocalTime = true;

  i18n.defaultLocale = "en_US.UTF-8";

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_29;
  virtualisation.docker.autoPrune.enable = true;

  # Exposes the GPU to containers via CDI: `docker run --device nvidia.com/gpu=all ...`
  hardware.nvidia-container-toolkit.enable = true;

  #
  # Gaming
  #
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  # Run games with `gamemoderun %command%` (Steam launch options) for a
  # performance governor and higher scheduling priority while playing.
  programs.gamemode.enable = true;

  security.sudo.wheelNeedsPassword = false;
  security.rtkit.enable = true;

  # Smart Card Reader Service
  # Used for YubiKey related operations.
  services.pcscd.enable = true;

  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    pulse.enable = true;
  };

  services.xserver = {
    enable = true;
    excludePackages = with pkgs; [ xterm ];
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.printing.enable = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  services.fwupd.enable = true;

  # SMART health monitoring for both NVMe drives; failures surface as GNOME
  # desktop notifications.
  services.smartd = {
    enable = true;
    notifications.systembus-notify.enable = true;
    notifications.wall.enable = true;
  };
  environment.systemPackages = with pkgs; [
    smartmontools

    # Gaming: Lutris is the unified library (Steam/GOG/Battle.net/local
    # exes); Heroic covers Epic/GOG titles Lutris handles poorly; ProtonPlus
    # installs GE-Proton and other compatibility tools.
    # Lutris is wrapped so Proton games use Wine's native Wayland driver
    # (XWayland can't carry HDR) and output HDR when the game enables it.
    # Override per game in Lutris' environment variables if one misbehaves.
    (pkgs.symlinkJoin {
      name = "lutris";
      paths = [ lutris ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/lutris \
          --set-default PROTON_ENABLE_WAYLAND 1 \
          --set-default PROTON_ENABLE_HDR 1
      '';
    })
    heroic
    protonplus
  ];

  services.journald.extraConfig = ''
    SystemMaxUse=1G
  '';

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      keep-outputs = true;
      keep-derivations = true;
      extra-substituters = [ "https://vicinae.cachix.org" ];
      extra-trusted-public-keys = [
        "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      ];
    };
    optimise.automatic = true;
  };

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 14d --keep 5";
    };
  };

  system.stateVersion = "26.05";
}
