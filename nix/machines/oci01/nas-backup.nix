{ config, pkgs, ... }:

# Off-site restic repository for the NAS home folder, pushed nightly by
# kube/nuc01/nas-backup over public SSH. The pusher's key is pinned to an
# append-only rclone server: it can add snapshots but can't delete or rewrite
# them, so a compromised home side can't take the off-site copy with it.
# Pruning happens here instead, which is why this host holds the repository
# password; the data on the volume is already restic-encrypted.
#
# The repository lives on its own block volume, formatted and initialised
# once by hand (README.md).
let
  mount = "/srv/backup";
  repo = "${mount}/restic";

  serve = pkgs.writeShellScript "nas-backup-serve" ''
    # Refuse rather than fill the boot volume if the backup volume is missing
    ${pkgs.util-linux}/bin/mountpoint -q ${mount} || { echo "${mount} is not mounted" >&2; exit 1; }
    exec ${pkgs.rclone}/bin/rclone serve restic --stdio --append-only ${repo}
  '';
in
{
  fileSystems.${mount} = {
    device = "/dev/disk/by-label/backup";
    fsType = "ext4";
    # Boot without it; serve and prune both need the mount and fail without it
    options = [
      "nofail"
      "x-systemd.device-timeout=30s"
    ];
  };

  # For the one-time init and for restores on this host
  environment.systemPackages = [ pkgs.restic ];

  users.groups.nas-backup = { };
  users.users.nas-backup = {
    isSystemUser = true;
    group = "nas-backup";
    # sshd runs the forced command through the login shell
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      "restrict,command=\"${serve}\" ${builtins.readFile ./nas-backup.pub}"
    ];
  };

  sops.secrets.nas-backup-restic-password = {
    sopsFile = ./secrets/nas-backup.enc.yaml;
    key = "restic-password";
    owner = "nas-backup";
  };

  systemd.services.nas-backup-prune = {
    description = "Prune and check the NAS restic repository";
    unitConfig.RequiresMountsFor = mount;
    path = [ pkgs.restic ];
    environment = {
      RESTIC_REPOSITORY = repo;
      RESTIC_PASSWORD_FILE = config.sops.secrets.nas-backup-restic-password.path;
      RESTIC_CACHE_DIR = "/var/cache/nas-backup";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "nas-backup";
      Group = "nas-backup";
      CacheDirectory = "nas-backup";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
    script = ''
      # Waits out a nightly push that's still running
      restic forget --prune --retry-lock 3h --host nas \
        --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --keep-yearly 3

      # A different tenth of the pack data each month
      restic check --read-data-subset="$(( $(date +%-m) % 10 + 1 ))/10"
    '';
  };

  # After the 01:00 push, ahead of the 04:00 upgrade window
  systemd.timers.nas-backup-prune = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-01 02:00";
      Persistent = true;
    };
  };
}
