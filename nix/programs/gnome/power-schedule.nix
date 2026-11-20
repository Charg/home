# Time-of-day screen lock and suspend. During work hours (Mon-Fri 08:00-18:00)
# the screen still blanks on idle but doesn't lock and the machine never
# auto-suspends; outside them it locks on blank and suspends after 2h idle.
#
# The keys below are owned by this script, not dconf.settings, so a
# home-manager switch doesn't reset them. Idle inhibitors (Caffeine,
# gnome-session-inhibit) still take precedence.
{ lib, pkgs, ... }:

let
  dconf = "${pkgs.dconf}/bin/dconf";

  apply = pkgs.writeShellScript "gnome-power-schedule" ''
    set -eu
    dow=$(${pkgs.coreutils}/bin/date +%u)
    hr=$(${pkgs.coreutils}/bin/date +%H)

    if (( dow <= 5 && 10#$hr >= 8 && 10#$hr < 18 )); then
      ${dconf} write /org/gnome/desktop/screensaver/lock-enabled false
      ${dconf} write /org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type "'nothing'"
    else
      ${dconf} write /org/gnome/desktop/screensaver/lock-enabled true
      ${dconf} write /org/gnome/desktop/screensaver/lock-delay "uint32 0"
      ${dconf} write /org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type "'suspend'"
      ${dconf} write /org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-timeout 7200
    fi
  '';
in

{
  systemd.user.services.gnome-power-schedule = {
    Unit = {
      Description = "Apply time-of-day GNOME lock and suspend settings";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${apply}";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.timers.gnome-power-schedule = {
    Unit.Description = "Switch GNOME lock and suspend settings at work-hour boundaries";
    Timer = {
      OnCalendar = "Mon..Fri 08,18:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Re-apply after a switch in case dconfSettings touched these keys.
  home.activation.gnomePowerSchedule = lib.hm.dag.entryAfter [ "dconfSettings" "reloadSystemd" ] ''
    if [[ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
      run ${apply} || true
    fi
  '';
}
