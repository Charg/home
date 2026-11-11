{
  inputs,
  lib,
  currentSystemUser,
  ...
}:

let
  home = "/home/${currentSystemUser}";
in
{
  imports = [ inputs.moonshine.nixosModules.default ];

  # Moonshine game stream host, an alternative to Helios (helios.nix) for
  # comparing HDR streaming. Each stream gets its own headless compositor
  # (ferriscope) on the 4080, separate from the GNOME session. HDR comes from
  # ferriscope's Vulkan WSI layer, not the Wayland colour-management protocol,
  # so Proton games stay on Xwayland (no PROTON_ENABLE_WAYLAND).
  #
  # Both hosts use the default GameStream ports, so run only one at a time.
  # Started by hand like Helios: `sudo systemctl start moonshine`, then pair at
  # http://localhost:47989/pin. Check the setup with `moonshine healthcheck`.
  services.moonshine = {
    enable = true;
    user = currentSystemUser;
    # The user's uid isn't declared in the config, so the module can't derive it.
    uid = 1000;
    openFirewall = true;

    settings = {
      name = "Moonshine";

      application = [
        {
          title = "Cyberpunk 2077";
          # Run umu directly, not through Lutris: if desktop Lutris is already
          # running, a Lutris launch opens the game on GNOME instead
          # (hgaiser/moonshine#233). Same exe, prefix and Proton as the Lutris
          # entry.
          command = [
            "/run/current-system/sw/bin/umu-run"
            "/mnt/windows/Games/Cyberpunk 2077/bin/x64/Cyberpunk2077.exe"
          ];
          env = {
            GAMEID = "umu-1091500";
            WINEPREFIX = "${home}/Games/cyberpunk-2077";
            PROTONPATH = "${home}/.local/share/Steam/compatibilitytools.d/GE-Proton11-11-x86_64";
            PROTON_ENABLE_HDR = "1";
            # VKD3D games freeze on NVIDIA when HDR is turned on under Moonshine
            # unless present_wait is off (hgaiser/moonshine#203).
            VKD3D_DISABLE_EXTENSIONS = "VK_KHR_present_wait,VK_KHR_present_wait2";
          };
        }
      ];
    };
  };

  # The module starts Moonshine at boot. Leave it to be started by hand so it
  # doesn't hold the GameStream ports when Helios is in use.
  systemd.services.moonshine = {
    wantedBy = lib.mkForce [ ];
    # Render and encode on the 4080. Moonshine already picks the
    # lowest-numbered render node, but that numbering isn't stable.
    environment.MOONSHINE_RENDER_NODE = "/dev/dri/by-path/pci-0000:01:00.0-render";
  };
}
