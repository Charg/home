{ ... }:

# Key-only SSH for every host that runs sshd. Imported by each machine
# config rather than applied globally so the Darwin and WSL hosts stay out.
# The initrd unlock sshd (initrd-ssh-unlock.nix) is a separate daemon and
# already accepts only the forced-command key.
{
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };
}
