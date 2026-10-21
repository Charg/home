# Home-manager settings specific to tortuga's display: an Odyssey OLED G9
# (G95SC, 49" 32:9). Shared GNOME settings live in programs/gnome/hm.nix.
{ lib, ... }:

{
  # GNOME can't persist display changes made in Settings while this file is
  # managed here.
  xdg.configFile."monitors.xml".text = import ./monitors.nix { inherit lib; };

  # At scale 1 and ~109 PPI, the shared Inter 12 renders at ~16px; GNOME's
  # layouts are designed around its 11pt default.
  gtk.font.size = lib.mkForce 11;
  dconf.settings."org/gnome/desktop/interface".document-font-name = lib.mkForce "Inter 11";

  # Blank the OLED quickly to limit burn-in, but keep the machine awake
  # far longer than GNOME's 15-minute default so downloads, builds and the
  # GPU node keep running.
  dconf.settings."org/gnome/desktop/session".idle-delay = lib.hm.gvariant.mkUint32 300;
  dconf.settings."org/gnome/settings-daemon/plugins/power" = {
    sleep-inactive-ac-type = "suspend";
    sleep-inactive-ac-timeout = 7200;
  };

  dconf.settings."org/gnome/mutter".experimental-features = [
    # Needed for blur-free fractional scaling; inert at scale 1.
    "scale-monitor-framebuffer"
    # Lets X11 apps (Steam, some games) render at native res instead of
    # being upscaled by the compositor.
    "xwayland-native-scaling"
  ];
}
