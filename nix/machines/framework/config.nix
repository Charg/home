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

  networking.firewall.allowedUDPPorts = [
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

    "wireplumber/scripts/wavedevicefix.lua".text = ''
      -- Fix for Wave XLR / Wave 3 / Wave 1 / XLR Dock microphone not working while playback is active.
      -- https://github.com/jmansar/wavexlr-on-linux-cfg
      --
      -- This script creates a link between Wave device source (mirophone input) and a virtual null sink (output)
      -- in order to force the device to start a microphone capture before the playback is activated.
      -- After the link is estabilished it creates Wave device sink (playback output).

      -- BEGIN USER CONFIGURATION

      -- If you need to customize the sink node that is created by the script
      -- you can add the additional properties below
      CONFIG_SINK_ADDITIONAL_PROPERTIES = {
          -- disables session suspend on idle for the sink playback
          -- helps with potential audio playback delays and audio popping
          ["session.suspend-timeout-seconds"] = "0"
      }

      -- END USER CONFIGURATION
      log = Log.open_topic("s-wavedevicefix")

      -- read arguments passed to the script from the wireplumber config file
      local scriptArgs = ...
      if scriptArgs ~= nil then
          scriptArgs = scriptArgs:parse(1)
      else
          scriptArgs = {}
      end

      CONFIG_WAVE_DEVICE_SOURCE_NAME = "wavexlr-source"
      CONFIG_WAVE_DEVICE_SINK_NAME = "wavexlr-sink"
      CONFIG_WAVE_DEVICE_DISPLAY_NAME = "WaveXLR"

      if scriptArgs["device"] == "wave3" then
          CONFIG_WAVE_DEVICE_SOURCE_NAME = "wave3-source"
          CONFIG_WAVE_DEVICE_SINK_NAME = "wave3-sink"
          CONFIG_WAVE_DEVICE_DISPLAY_NAME = "Wave3"

          log.notice("Use configuration for Wave3 device")
      elseif scriptArgs["device"] == "wave1" then
          CONFIG_WAVE_DEVICE_SOURCE_NAME = "wave1-source"
          CONFIG_WAVE_DEVICE_SINK_NAME = "wave1-sink"
          CONFIG_WAVE_DEVICE_DISPLAY_NAME = "Wave1"

          log.notice("Use configuration for Wave1 device")
      elseif scriptArgs["device"] == "xlrdock" then
          CONFIG_WAVE_DEVICE_SOURCE_NAME = "xlrdock-source"
          CONFIG_WAVE_DEVICE_SINK_NAME = "xlrdock-sink"
          CONFIG_WAVE_DEVICE_DISPLAY_NAME = "XLRDock"

          log.notice("Use configuration for XLRDock device")
      else
          log.notice("Use configuration for WaveXLR device")
      end


      waveDeviceSourceOm = ObjectManager {
          Interest {
              type = "node",
              Constraint { "node.name", "matches", CONFIG_WAVE_DEVICE_SOURCE_NAME },
          }
      }

      linkOm = ObjectManager {
          Interest {
              type = "link",
          }
      }

      devicesOm = ObjectManager {
          Interest {
              type = "device",
          }
      }

      waveDeviceSinkNode = nil
      nullSinkForWaveDeviceSource = nil
      nullSinkLink = nil

      function createLinkForWaveDeviceSource(waveDeviceSourceNode)
          local outPort = nil
          local inPort = nil

          local outInterest = Interest {
              type = "port",
              Constraint { "node.id", "equals", waveDeviceSourceNode.properties["object.id"] },
              Constraint { "port.direction", "equals", "out" }
          }

          local inInterest = Interest {
              type = "port",
              Constraint { "node.id", "equals", nullSinkForWaveDeviceSource.properties["object.id"] },
              Constraint { "port.direction", "equals", "in" }
          }

          local portOm = ObjectManager {
              Interest {
                  type = "port",
              }
          }

          function onPortAdded()
              if not nullSinkLink then
                  for port in portOm:iterate(outInterest) do
                      outPort = port
                  end

                  for port in portOm:iterate(inInterest) do
                      inPort = port
                  end

                  if inPort and outPort and
                     inPort.properties["object.id"] and
                     outPort.properties["object.id"] and
                     waveDeviceSourceNode.properties["object.id"] and
                     nullSinkForWaveDeviceSource.properties["object.id"] then
                      local args = {
                          ["link.input.node"] = nullSinkForWaveDeviceSource.properties["object.id"],
                          ["link.input.port"] = inPort.properties["object.id"],

                          ["link.output.node"] = waveDeviceSourceNode.properties["object.id"],
                          ["link.output.port"] = outPort.properties["object.id"],
                      }

                      log:notice("Creating link between null sink and " ..
                          CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source. Ports: " ..
                          args["link.input.node"] ..
                          "-" ..
                          args["link.input.port"] .. " -> " .. args["link.output.node"] .. "-" .. args["link.output.port"])

                      nullSinkLink = Link("link-factory", args)

                      nullSinkLink:activate(Feature.Proxy.BOUND, function(n, err)
                          if err then
                              log:warning("Failed to create link between null sink and " ..
                                  CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source"
                                  .. ": " .. tostring(err))
                              node = nil
                          else
                              log:notice("Created link between null sink and " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source")
                          end
                      end)
                  end
              end
          end

          portOm:connect("object-added", onPortAdded)
          portOm:activate()
      end

      function onLinkCreated(_, link)
          if nullSinkLink and link.properties["object.id"] == nullSinkLink.properties["object.id"] then
              for node in waveDeviceSourceOm:iterate() do
                  createWaveDeviceSink(node)
              end
          end
      end

      function createWaveDeviceSink(sourceNode)
          local deviceInterest = Interest {
              type = "device",
              Constraint { "object.id", "equals", sourceNode.properties["device.id"] }
          }

          for device in devicesOm:iterate(deviceInterest) do
              local sinkNodeProperties = {
                  ["device.id"] = sourceNode.properties["device.id"],
                  ["factory.name"] = "api.alsa.pcm.sink",
                  ["node.name"] = CONFIG_WAVE_DEVICE_SINK_NAME,
                  ["node.description"] = CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " Sink",
                  ["node.nick"] = CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " Sink",
                  ["media.class"] = "Audio/Sink",
                  ["api.alsa.path"] = sourceNode.properties["api.alsa.path"],
                  ["api.alsa.pcm.card"] = sourceNode.properties["api.alsa.pcm.card"],
                  ["api.alsa.pcm.stream"] = "playback",
                  ["alsa.resolution_bits"] = "24",
                  ["audio.channels"] = "2",
                  ["audio.position"] = "FL,FR",
                  ["priority.driver"] = "1000",
                  ["priority.session"] = "1000",
                  ["node.pause-on-idle"] = "false",
                  ["card.profile.device"] = "3",
                  ["device.profile.description"] = "Analog Stereo",
                  ["device.profile.name"] = "analog-stereo",
                  ["port.group"] = "playback",
              }

              for k, v in pairs(device.properties) do
                  if k:find("^api%.alsa%.card%..*") then
                      sinkNodeProperties[k] = v
                  end
              end

              for k, v in pairs(CONFIG_SINK_ADDITIONAL_PROPERTIES) do
                  sinkNodeProperties[k] = v
              end

              log:notice("Creating custom " ..
                  CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " sink. api.alsa.path: " .. sourceNode.properties["api.alsa.path"])

              waveDeviceSinkNode = Node("adapter", sinkNodeProperties)
              waveDeviceSinkNode:activate(Feature.Proxy.BOUND, function(n, err)
                  if err then
                      log:warning("Failed to create " .. sinkNodeProperties["node.name"]
                          .. ": " .. tostring(err))
                      waveDeviceSinkNode = nil
                  else
                      log:notice("Created custom " ..
                          CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " sink. object.id: " .. n.properties["object.id"])
                  end
              end)
          end
      end

      function onWaveDeviceSourceAdded(_, node)
          createLinkForWaveDeviceSource(node)
      end

      function createNullSink()
          local properties = {
              ["factory.name"] = "support.null-audio-sink",
              ["node.name"] = "null-sink-for-" .. CONFIG_WAVE_DEVICE_SOURCE_NAME,
              ["node.description"] = "Null Sink For " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " Source - do not use",
              ["node.nick"] = "Null Sink For " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " Source - do not use",
              ["media.class"] = "Audio/Sink",
              ["monitor.channel-volumes"] = "true",
              ["monitor.passthrough"] = "true",
              ["audio.channels"] = "1",
              ["audio.position"] = "MONO",
              ["node.passive"] = "false"
          }

          log:notice("Creating custom null sink for " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " Source")

          local node = Node("adapter", properties)

          node:activate(Feature.Proxy.BOUND, function(n, err)
              if err then
                  log:warning("Failed to create " .. properties["node.name"]
                      .. ": " .. tostring(err))
                  node = nil
              else
                  log:notice("Created null sink for " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source. object.id: " ..
                      n.properties["object.id"])
                  onNullSinkCreated();
              end
          end)

          return node
      end

      function onWaveDeviceSourceRemoved()
          if waveDeviceSinkNode then
              log:notice("Removing custom " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " sink");
              waveDeviceSinkNode:request_destroy()
              waveDeviceSinkNode = nil
          end

          if nullSinkLink then
              log:notice("Removing null sink link");
              nullSinkLink:request_destroy()
              nullSinkLink = nil
          end
      end

      function onNullSinkCreated()
          log:notice("Activate event listeners");

          linkOm:activate()
          linkOm:connect("object-added", onLinkCreated)
          waveDeviceSourceOm:connect("object-added", onWaveDeviceSourceAdded)
          waveDeviceSourceOm:connect("object-removed", onWaveDeviceSourceRemoved)
          waveDeviceSourceOm:activate()
      end

      nullSinkForWaveDeviceSource = createNullSink();
      devicesOm:activate()

      log:notice("script initialized")
    '';
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

  # Enable thunderbold
  services.hardware.bolt.enable = true;

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
  services.fwupd = {
    enable = true;
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

  fonts.packages = with pkgs; [
    inter
    jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  # https://github.com/nix-community/nix-ld
  # Run unpatched dynamic binaries on NixOS0
  programs.nix-ld.enable = true;

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
