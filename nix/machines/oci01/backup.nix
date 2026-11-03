{ config, pkgs, ... }:

# Daily encrypted snapshot of the headscale state. Losing the noise key or the
# database means re-registering every node. The snapshot is encrypted to the
# personal age key, so the box holding the copy can't read it. A home host
# pulls it over SSH (kube/nuc01/headscale-backup); this host holds no
# credentials for anything at home.
#
# Restore:
#   age -d -i <identity> headscale-<date>.tar.age | tar -x -C <dir>
#   systemctl stop headscale
#   install -o headscale -g headscale -m 600 <dir>/* /var/lib/headscale/
#   rm -f /var/lib/headscale/db.sqlite-{wal,shm}
#   systemctl start headscale
let
  hs = config.services.headscale.settings;
  dir = "/var/backup/headscale";
in
{
  systemd.services.headscale-backup = {
    description = "Encrypted snapshot of headscale state";
    after = [ "headscale.service" ];
    path = [
      pkgs.age
      pkgs.gnutar
      pkgs.sqlite
    ];
    serviceConfig = {
      Type = "oneshot";
      # Owns everything it reads; the setgid output dir hands the snapshot to
      # the puller's group without needing to be a member of it
      User = "headscale";
      Group = "headscale";
      UMask = "0077";
      PrivateTmp = true;
    };
    script = ''
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT

      # Consistent copy of a live WAL database; a plain cp can catch it mid-write
      sqlite3 ${hs.database.sqlite.path} ".timeout 30000" "VACUUM INTO '$tmp/db.sqlite'"
      cp ${hs.noise.private_key_path} ${hs.derp.server.private_key_path} "$tmp/"

      tar -C "$tmp" -c . | age -R ${../../common/keys/age-personal.pub} > ${dir}/latest.tar.age.new
      chmod 640 ${dir}/latest.tar.age.new
      mv ${dir}/latest.tar.age.new ${dir}/latest.tar.age
    '';
  };

  # Ahead of the 04:00 upgrade window; the home pull runs at 07:00
  systemd.timers.headscale-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true;
    };
  };

  systemd.tmpfiles.rules = [ "d ${dir} 2750 headscale headscale-backup -" ];

  # Pull-only account: its one key can read the latest snapshot and nothing else
  users.groups.headscale-backup = { };
  users.users.headscale-backup = {
    isSystemUser = true;
    group = "headscale-backup";
    # sshd runs the forced command through the login shell
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      "restrict,command=\"cat ${dir}/latest.tar.age\" ${builtins.readFile ./backup-puller.pub}"
    ];
  };
}
