{
  config,
  currentSystemName,
  currentSystemUser,
  ...
}:

# The login password for this host's primary user comes from a per-host
# SOPS file rather than a hash committed in the clear. The file is encrypted
# to the personal age key and to this host's SSH host key (see .sops.yaml),
# so sops-nix can decrypt it at activation with no interaction.
#
# Create or rotate it with:
#   mkpasswd -m yescrypt            # paste the result as `user-password:`
#   sops nix/machines/<host>/secrets/users.enc.yaml
#
# `neededForUsers` decrypts it before users are created, which is what
# `hashedPasswordFile` requires.
{
  sops.secrets.user-password = {
    sopsFile = ../machines/${currentSystemName}/secrets/users.enc.yaml;
    neededForUsers = true;
  };

  users.users.${currentSystemUser}.hashedPasswordFile = config.sops.secrets.user-password.path;

  # NixOS only writes a declared password into an existing /etc/shadow entry
  # when users are immutable (update-users-groups.pl keeps existing entries
  # untouched under mutableUsers, FIXME and all). Without this the file above
  # would only ever apply on first account creation, and `passwd` changes
  # would silently diverge from the repo.
  users.mutableUsers = false;
}
