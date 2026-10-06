{ config, pkgs, ... }:

{
  services.openiscsi = {
    enable = true;
    name = "iqn.2005-03.org.open-iscsi:${config.networking.hostName}";
  };

  # The synology-csi node plugin doesn't call iscsiadm directly - it chroots
  # into the bind-mounted host root and re-execs "iscsiadm" against
  # PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  # (see chroot/chroot.sh in the synology-csi source). NixOS has no /usr/bin
  # or /sbin - installed packages only live under /run/current-system/sw/bin
  # - so services.openiscsi.enable alone isn't enough; the chroot still
  # can't find the binary. Symlink it into the one FHS path the chroot
  # script checks first.
  systemd.tmpfiles.rules = [
    "d /usr/local/sbin 0755 root root -"
    "L+ /usr/local/sbin/iscsiadm - - - - ${pkgs.openiscsi}/bin/iscsiadm"
  ];
}
