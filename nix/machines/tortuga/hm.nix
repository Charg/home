# Home-manager settings specific to tortuga's display: an Odyssey OLED G9
# (G95SC, 49" 32:9). Shared GNOME settings live in programs/gnome/hm.nix.
{ ... }:

{
  # Mutter otherwise picks the EDID-preferred 3840x1080, which the panel
  # upscales to its native 5120x1440 and blurs text. 1.25 keeps the UI
  # roughly the size it was at 3840x1080 while rendering at native res.
  # 240 Hz is only offered as a VRR mode over HDMI; fixed 120 Hz avoids
  # OLED VRR flicker. GNOME can't persist display changes made in Settings
  # while this file is managed here.
  xdg.configFile."monitors.xml".text = ''
    <monitors version="2">
      <configuration>
        <layoutmode>logical</layoutmode>
        <logicalmonitor>
          <x>0</x>
          <y>0</y>
          <scale>1.25</scale>
          <primary>yes</primary>
          <monitor>
            <monitorspec>
              <connector>HDMI-3</connector>
              <vendor>SAM</vendor>
              <product>Odyssey G95SC</product>
              <serial>H1AK500000</serial>
            </monitorspec>
            <mode>
              <width>5120</width>
              <height>1440</height>
              <rate>119.999755859375</rate>
            </mode>
          </monitor>
        </logicalmonitor>
      </configuration>
    </monitors>
  '';

  dconf.settings."org/gnome/mutter".experimental-features = [
    # Required for fractional (1.25) scaling without blur.
    "scale-monitor-framebuffer"
    # Lets X11 apps (Steam, some games) render at native res instead of
    # being upscaled by the compositor.
    "xwayland-native-scaling"
  ];
}
