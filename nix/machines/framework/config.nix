{
  config,
  lib,
  pkgs,
  inputs,
  host,
  ...
}:

let
  netcheck = pkgs.local.netcheck;

  # Runs as root via the NetworkManager dispatcher. Notify-only: tearing down a
  # compose stack mid-flight is worse than the address collision.
  netcheckDispatcher = pkgs.writeShellScript "netcheck-dispatcher" ''
    set -euo pipefail

    interface="$1"
    action="$2"

    case "$action" in
      up | dhcp4-change) ;;
      *) exit 0 ;;
    esac

    if ! output=$(${netcheck}/bin/netcheck --json 2>&1); then
      summary=$(echo "$output" | ${pkgs.jq}/bin/jq -r '
        (.fatal[]? | "FATAL: gateway \(.gateway) on \(.gateway_interface) is inside \(.local_subnet) (\(.owner))"),
        (.conflicts[]? | "CONFLICT: \(.uplink_subnet) on \(.uplink_interface) overlaps \(.local_subnet) (\(.owner))")
      ' 2>/dev/null || true)

      ${pkgs.util-linux}/bin/logger -t netcheck "network conflict detected on $interface ($action): $summary"

      if [ -n "''${summary:-}" ]; then
        ${pkgs.sudo}/bin/sudo -u ${host.user} \
          DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(${pkgs.coreutils}/bin/id -u ${host.user})/bus \
          ${pkgs.libnotify}/bin/notify-send \
          -u critical \
          "Network conflict on $interface" \
          "$summary" || true
      fi
    fi

    exit 0
  '';
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    ./hardware-configuration.nix
    ./disk-config.nix
    ./netmode.nix
  ];

  home-manager.users.${host.user}.imports = [ ../../programs/git/signing.nix ];

  #
  # Bootloader
  #
  boot.loader.systemd-boot.enable = true;
  # resolves an issues with virtualbox 6.12. https://github.com/NixOS/nixpkgs/issues/363887#issuecomment-2536693220
  boot.kernelParams = [ "kvm.enable_virt_at_load=0" ];

  # Unlock cryptroot with the YubiKey's FIDO2 token if it's plugged in, else
  # fall back to the passphrase after token-timeout. Enrol the key with:
  #   systemd-cryptenroll --fido2-device=auto --fido2-with-client-pin=no \
  #     --fido2-with-user-presence=no /dev/disk/by-partlabel/disk-main-luks
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = [
    "fido2-device=auto"
    "token-timeout=5s"
  ];

  #
  # Networking
  #
  networking.hostName = "framework13";
  networking.wireguard.enable = true;

  networking.firewall.allowedUDPPorts = [
    51820 # WireGuard
  ];

  # kind pod traffic (10.244.0.0/16) reaches the host un-NATed over the Docker bridge, but
  # the pod routes only exist inside the kind node container, so rpfilter drops it.
  # Exempt that source range, scoped to Docker bridges so it can't be spoofed elsewhere.
  networking.firewall.extraCommands = ''
    iptables -t mangle -I nixos-fw-rpfilter -i br-+ -s 10.244.0.0/16 -j RETURN
  '';

  # Desktop notification (and journal log) when joining a network whose uplink
  # subnet overlaps a local Docker/VirtualBox network. See nix/packages/netcheck.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = netcheckDispatcher;
    }
  ];

  environment.systemPackages = [
    netcheck
    pkgs.pam_u2f # pamu2fcfg, for registering FIDO2 keys (see security.pam below)
  ];

  # Name my AV Access ethernet adapter
  systemd.network.links."10-av-eth" = {
    matchConfig.MACAddress = "34:1b:22:85:cb:3f";
    linkConfig.Name = "aveth0";
  };

  #
  # Hardware
  #
  # Disable autosuspend for Elgato Wave XLR to prevent USB drops (-110 errors)
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="007d", ATTR{power/control}="on"
  '';

  # WirePlumber fix for Elgato Wave XLR: forces mic capture before playback starts,
  # preventing the buggy usb_set_interface resume path that causes -110 lockups.
  # https://github.com/jmansar/wavexlr-on-linux-cfg
  environment.etc = {
    "wireplumber/wireplumber.conf.d/51-wavexlr.conf".text = ''
      wireplumber.components = [
        {
          name = /etc/wireplumber/scripts/wavedevicefix.lua
          type = script/lua
          arguments = { device = "wavexlr" }
        }
      ]

      monitor.alsa.rules = [
        {
          matches = [
            {
              node.name = "~alsa_output.usb-Elgato_Systems_Elgato_Wave_XLR_*"
            }
          ]
          actions = {
            update-props = {
              node.disabled = true
            }
          }
        },
        {
          matches = [
            {
              node.name = "~alsa_input.usb-Elgato_Systems_Elgato_Wave_XLR_*"
            }
          ]
          actions = {
            update-props = {
              node.name = "wavexlr-source"
            }
          }
        }
      ]
    '';

    "wireplumber/scripts/wavedevicefix.lua".text = builtins.readFile ./wavedevicefix.lua;
  };

  #
  # System
  #
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

  virtualisation.docker.daemon.settings = {
    # Stay out of every RFC1918 range that airline/hotel DHCP hands out. 198.18.0.0/15
    # is IANA-reserved for RFC 2544 benchmarking and essentially never appears on
    # real-world networks, unlike 172.16/12, 10/8, and 192.168/16.
    default-address-pools = [
      {
        base = "198.18.0.0/16";
        size = 24;
      }
      {
        base = "10.200.0.0/13";
        size = 24;
      }
    ];
  };
  virtualisation.virtualbox.host.enableExtensionPack = true;

  # VirtualBox's built-in host-only allowlist (192.168.56.0/21) collides with the
  # same private ranges hotel/office Wi-Fi hands out. Restrict it to the same
  # IANA-reserved 198.18.0.0/15 range used for the Docker pools above.
  environment.etc."vbox/networks.conf".text = ''
    * 198.19.128.0/21
    * fe80::/64
  '';

  # The lid sensos is flakey atm. Ignore it until I can fix it.
  services.logind.settings.Login.HandleLidSwitch = "ignore";

  # Hibernate is manual (`systemctl hibernate`) to the swap LV, which disko
  # sets as the resume device. Note the kernel refuses it while any process
  # holds memfd_secret memory (e.g. Bitwarden desktop).

  # Goodix reader in the power button. GDM runs fingerprint and password auth
  # in parallel; enrol with `fprintd-enroll`.
  services.fprintd.enable = true;

  # Pin origin/appid rather than letting pam_u2f derive them from the hostname.
  security.pam.u2f.settings = {
    userpresence = 0;
    origin = "pam://framework13";
    appid = "pam://framework13";
  };
  # gdm-password and the lock screen substack `login`; pam_u2f sits before
  # pam_unix, so a missing key fails the login even with the right password.
  security.pam.services.login.u2f = {
    enable = true;
    control = "required";
  };
  # gdm-fingerprint carries its own rule list and ignores the option above.
  # Run pam_u2f after pam_fprintd so the key is only checked once a finger
  # has matched.
  security.pam.services.gdm-fingerprint.rules.auth.u2f = {
    control = "required";
    modulePath = "${pkgs.pam_u2f}/lib/security/pam_u2f.so";
    order = config.security.pam.services.gdm-fingerprint.rules.auth.fprintd.order + 10;
    settings = config.security.pam.u2f.settings;
  };

  # Enable thunderbold
  services.hardware.bolt.enable = true;

  services.pipewire = {
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

  # Installed but not started at boot: `sudo systemctl start sshd` when needed.
  systemd.services.sshd.wantedBy = lib.mkForce [ ];

  # A simple daemon allowing you to update some devices' firmware
  # https://github.com/fwup-home/fwup
  # https://nixos.wiki/wiki/Fwupd
  services.fwupd = {
    daemonSettings = {
      DisabledPlugins = [
        "dfu"
        "fastboot"
      ];
    };
  };

  # Enable power-profiles-daemon, a DBus daemon
  # Recommended at https://wiki.nixos.org/wiki/Hardware/Framework/Laptop_13
  services.power-profiles-daemon.enable = true;

  # Don't catch up a missed 03:45 run on resume from suspend.
  nix.optimise.persistent = false;

  # Keep store optimisation out of the way of interactive use.
  systemd.services.nix-optimise.serviceConfig = {
    CPUWeight = "idle";
    CPUQuota = "100%";
    IOSchedulingClass = "idle";
    Nice = 19;
  };
}
