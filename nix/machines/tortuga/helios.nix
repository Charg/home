{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Upstream builds without CUDA, and on Linux NVENC is only compiled in with
  # it; without this the 4080 can't encode and Helios falls back to software.
  helios = (pkgs.callPackage "${inputs.helios}/packaging/nix/package.nix" { }).overrideAttrs (old: {
    # Build the flake input's source, not the release tag package.nix pins, so
    # the local branch is what runs. The input has no submodules, so take
    # their contents from the release source; the branch keeps its pins.
    src = pkgs.runCommand "helios-src" { passthru.rev = inputs.helios.rev; } ''
      cp -r ${inputs.helios} $out
      chmod -R u+w $out
      for dir in ${old.src}/third-party/*/; do
        name=$(basename "$dir")
        if [ -z "$(ls -A "$out/third-party/$name")" ]; then
          cp -r "$dir/." "$out/third-party/$name/"
        fi
      done
    '';
    nativeBuildInputs = old.nativeBuildInputs ++ [
      pkgs.cudaPackages.cuda_nvcc
      pkgs.autoAddDriverRunpath
    ];
    buildInputs = old.buildInputs ++ [ pkgs.cudaPackages.cuda_cudart ];
    cmakeFlags = map (
      flag: if flag == "-DSUNSHINE_ENABLE_CUDA:BOOL=FALSE" then "-DSUNSHINE_ENABLE_CUDA:BOOL=TRUE" else flag
    ) old.cmakeFlags;
  });

  # Sway with wlroots headless outputs patched to support HDR (BT.2020 + PQ),
  # from Helios's packaging. HDR also needs the Vulkan renderer.
  sway = helios.passthru.sway;

  # Helios picks its capture method at startup, before it would launch its own
  # private Sway, so started from GNOME (no wlroots screencopy, no KMS without
  # CAP_SYS_ADMIN) it finds nothing to capture. Started inside a Sway session
  # it uses that one instead, so run it as the only client of a headless Sway
  # and take the compositor down with it.
  #
  # Sway's stock config makes the session usable as a streamed desktop
  # ($mod+Return terminal, $mod+d launcher, bar). Exiting Sway would take
  # Helios down mid-stream, so that binding is removed.
  swayConfig = pkgs.writeText "helios-sway.conf" ''
    include ${sway}/etc/sway/config
    unbindsym $mod+Shift+e
    exec ${pkgs.runtimeShell} -c '${lib.getExe config.services.helios.package}; ${sway}/bin/swaymsg exit'
  '';

  # Helios only creates per-client displays for clients that negotiate the
  # Moonlight OS display-topology extension (Selene). Others, like Artemis,
  # stream the existing HEADLESS-1, which Sway starts at 1280x720. Set as a
  # global prep command in the web UI to switch it to the client's requested
  # mode and dynamic range before the stream and app start.
  helios-display-mode = pkgs.writeShellApplication {
    name = "helios-display-mode";
    runtimeInputs = [ sway ];
    text = ''
      hdr=off
      if [ "''${HELIOS_CLIENT_HDR:-false}" = true ]; then hdr=on; fi
      swaymsg output HEADLESS-1 mode "''${HELIOS_CLIENT_WIDTH}x''${HELIOS_CLIENT_HEIGHT}@''${HELIOS_CLIENT_FPS}Hz" hdr "$hdr"
    '';
  };

  # On first start Helios copies its default apps.json out of the store, keeping
  # the store's read-only mode, and saves from the web UI then fail silently.
  # Seed a writable copy instead, and repair one that is already read-only.
  appsJson = pkgs.writeShellScript "helios-apps-json" ''
    apps="''${XDG_CONFIG_HOME:-$HOME/.config}/helios/apps.json"
    if [ -e "$apps" ]; then
      ${pkgs.coreutils}/bin/chmod u+w "$apps"
    else
      ${pkgs.coreutils}/bin/install -Dm644 ${config.services.helios.package}/assets/apps.json "$apps"
    fi
  '';
in
{
  imports = [ "${inputs.helios}/packaging/nix/module.nix" ];

  # Helios game stream host. Clients get their own displays in a headless Sway
  # session rendered on the 4080, so the G9 and the GNOME session are left
  # alone. No KMS capture, so no CAP_SYS_ADMIN wrapper.
  #
  # Keyboard and mouse go to Sway as virtual devices of that compositor, so
  # they never reach the GNOME session. Controllers are system-wide uinput
  # devices, which games read directly.
  #
  # Started by hand: `systemctl --user start helios`, web UI on
  # https://localhost:47990.
  services.helios = {
    enable = true;
    package = helios;
    autoStart = false;
    openFirewall = true;
  };

  environment.systemPackages = [
    helios-display-mode
    # Launches Proton games directly, e.g. with
    # PROTON_ENABLE_WAYLAND/PROTON_ENABLE_HDR for HDR streams.
    pkgs.umu-launcher
    # Terminal and launcher that Sway's stock config binds.
    pkgs.foot
    pkgs.wmenu
  ];

  systemd.user.services.helios = {
    environment = {
      WLR_BACKENDS = "headless";
      WLR_HEADLESS_OUTPUTS = "1";
      WLR_LIBINPUT_NO_DEVICES = "1";
      # Render on the 4080 rather than the iGPU.
      WLR_RENDER_DRM_DEVICE = "/dev/dri/by-path/pci-0000:01:00.0-render";
      # HDR outputs need output color transforms, which only the Vulkan
      # renderer has.
      WLR_RENDERER = "vulkan";
    };
    serviceConfig = {
      ExecStartPre = appsJson;
      ExecStart = lib.mkForce "${lib.getExe sway} --unsupported-gpu --config ${swayConfig}";
      # Sway sets its own WAYLAND_DISPLAY for Helios; GNOME's Xwayland DISPLAY
      # would otherwise leak through.
      UnsetEnvironment = [ "DISPLAY" ];
    };
  };

  # DS5 emulation needs /dev/uhid. Upstream loads the module via modules-load.d,
  # which NixOS ignores; without it /dev/uhid stays a root-only static node.
  boot.kernelModules = [ "uhid" ];

  # Root helper for USB forwarding and read-only disk access; neither is used.
  systemd.services.helios-usb-helper.enable = false;
}
