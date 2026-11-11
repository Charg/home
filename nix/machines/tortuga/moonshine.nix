{
  inputs,
  lib,
  pkgs,
  currentSystemUser,
  ...
}:

let
  # Fills in ~/.local/share/lutris/coverart for installed Lutris games, which
  # is where the Lutris scanner below takes box art from: Helios's covers
  # first, then IGDB via LizardByte's GameDB. Runs before Moonshine starts;
  # run `lutris-covers` by hand after adding a game while it's up.
  lutris-covers = pkgs.writers.writePython3Bin "lutris-covers" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./lutris-covers.py);

  # Proton environment for every streamed game. The lutris wrapper in
  # config.nix defaults to PROTON_ENABLE_WAYLAND=1, which Helios's Sway needs
  # for HDR; Moonshine's compositor serves no colour-management protocol, so
  # games stay on Xwayland and get HDR through the WSI layer instead. The
  # wrapper uses --set-default, so these win.
  protonEnv = {
    PROTON_ENABLE_WAYLAND = "0";
    PROTON_ENABLE_HDR = "1";
    # VKD3D games freeze on NVIDIA when HDR is turned on under Moonshine
    # unless present_wait is off (hgaiser/moonshine#203).
    VKD3D_DISABLE_EXTENSIONS = "VK_KHR_present_wait,VK_KHR_present_wait2";
  };

  # Lutris is single-instance: if it's already open on the GNOME desktop, a
  # launch from Moonshine opens the game there instead (hgaiser/moonshine#233).
  # Close it first, waiting up to 10s. This also ends anything that desktop
  # Lutris is running. Lutris itself is python running .lutris-wrapped inside
  # its FHS sandbox; [.] keeps the pattern from matching this script.
  closeDesktopLutris = [
    (lib.getExe pkgs.bash)
    "-c"
    ''
      lutris='lutris-unwrapped-[^/]*/bin/[.]lutris-wrapped'
      ${pkgs.procps}/bin/pkill -f "$lutris" || exit 0
      for _ in $(${pkgs.coreutils}/bin/seq 10); do
        ${pkgs.procps}/bin/pgrep -f "$lutris" >/dev/null || exit 0
        ${pkgs.coreutils}/bin/sleep 1
      done
    ''
  ];
in
{
  imports = [ inputs.moonshine.nixosModules.default ];

  # Moonshine game stream host, an alternative to Helios (helios.nix) for
  # comparing HDR streaming. Each stream gets its own headless compositor
  # (ferriscope) on the 4080, separate from the GNOME session. HDR comes from
  # ferriscope's Vulkan WSI layer, not the Wayland colour-management protocol,
  # so Proton games stay on Xwayland.
  #
  # Both hosts use the default GameStream ports, so run only one at a time.
  # Started by hand like Helios: `sudo systemctl start moonshine`. Pair at
  # http://localhost:47989/pin?uniqueid=<client id>; the id is in the journal
  # when a client starts pairing, and plain /pin only works for clients with
  # Moonlight's default id. Check the setup with `moonshine healthcheck`.
  services.moonshine = {
    enable = true;
    user = currentSystemUser;
    # The user's uid isn't declared in the config, so the module can't derive it.
    uid = 1000;
    openFirewall = true;

    settings = {
      name = "Moonshine";

      # Every installed Lutris game, read from Lutris's database at runtime and
      # rescanned when it changes, so new games show up without a rebuild.
      application_scanner = [
        {
          type = "lutris";
          command = [
            "/run/current-system/sw/bin/lutris"
            "lutris:rungame/{slug}"
          ];
          pre_command = [ closeDesktopLutris ];
          env = protonEnv;
        }
      ];
    };
  };

  environment.systemPackages = [ lutris-covers ];

  # Lets Moonshine hold a logind sleep inhibitor while streaming (polkit rule
  # shipped in the package), so GNOME's idle suspend, which never sees the
  # streamed input, doesn't put the machine to sleep mid-stream.
  users.users.${currentSystemUser}.extraGroups = [ "moonshine" ];

  # The module starts Moonshine at boot. Leave it to be started by hand so it
  # doesn't hold the GameStream ports when Helios is in use.
  systemd.services.moonshine = {
    wantedBy = lib.mkForce [ ];
    # Render and encode on the 4080. Moonshine already picks the
    # lowest-numbered render node, but that numbering isn't stable.
    environment.MOONSHINE_RENDER_NODE = "/dev/dri/by-path/pci-0000:01:00.0-render";
    # Covers for games added since the last start. Runs as the Moonshine user;
    # a failed lookup (e.g. offline) doesn't stop Moonshine starting.
    serviceConfig.ExecStartPre = "-${lib.getExe lutris-covers}";
  };
}
