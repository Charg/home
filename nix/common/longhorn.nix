{ config, pkgs, ... }:

{
  assertions = [
    {
      assertion = config.services.openiscsi.enable;
      message = "longhorn: the v1 data engine attaches volumes over iSCSI; import synology-iscsi.nix";
    }
  ];

  # Longhorn runs host tools (iscsiadm, mount, blkid, ...) via nsenter with its
  # container's FHS PATH, which finds nothing on NixOS. /usr/local/bin is on
  # that PATH but not on NixOS's own, so pointing it at the system profile is
  # side-effect free. See longhorn/longhorn#2166.
  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin"
  ];

  # mount.nfs for RWX volumes; Longhorn's environment check expects it.
  environment.systemPackages = [ pkgs.nfs-utils ];
}
