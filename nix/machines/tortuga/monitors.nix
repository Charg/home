# Mutter monitors.xml for tortuga's Odyssey OLED G9 (G95SC, 49" 32:9).
# Used both as the user's ~/.config/monitors.xml (hm.nix) and as the
# system-wide /etc/xdg/monitors.xml read by the GDM greeter (config.nix).
#
# Mutter otherwise picks the EDID-preferred 3840x1080, which the panel
# upscales to its native 5120x1440 and blurs text. At ~109 PPI (same as
# a 27" 1440p) the panel wants scale 1.0; 1.25 made the UI oversized.
# 240 Hz is only offered as a VRR mode over HDMI; fixed 120 Hz avoids
# OLED VRR flicker. bt2100 is GNOME's HDR mode.
#
# The greeter must use the same mode: if it doesn't, the switch to the user
# session changes resolution, refresh rate and HDR at once, and the panel
# goes black for 5-10s while it re-syncs.
{ lib }:
let
  # The kernel numbers connectors across both GPUs in driver probe
  # order, so the 4080's HDMI port isn't always HDMI-1. Mutter matches
  # connector names exactly, so emit one configuration per candidate.
  connectors = [
    "HDMI-1"
    "HDMI-2"
    "HDMI-3"
  ];
  configuration = connector: ''
    <configuration>
      <layoutmode>logical</layoutmode>
      <logicalmonitor>
        <x>0</x>
        <y>0</y>
        <scale>1</scale>
        <primary>yes</primary>
        <monitor>
          <monitorspec>
            <connector>${connector}</connector>
            <vendor>SAM</vendor>
            <product>Odyssey G95SC</product>
            <serial>H1AK500000</serial>
          </monitorspec>
          <mode>
            <width>5120</width>
            <height>1440</height>
            <rate>119.999755859375</rate>
          </mode>
          <colormode>bt2100</colormode>
        </monitor>
      </logicalmonitor>
    </configuration>
  '';
in
''
  <monitors version="2">
  ${lib.concatMapStrings configuration connectors}</monitors>
''
