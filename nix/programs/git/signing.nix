# Commit signing with a no-touch ed25519-sk key on the YubiKey that stays
# plugged into the machine, so commits (including rebases and agent commits)
# sign without a tap. Import only on hosts that have such a key: the handle
# at ~/.ssh/id_ed25519_sk_signing is generated per machine, is only usable
# with that YubiKey attached, and isn't managed here.
{ config, ... }:

let
  # Every machine's signing key, so commits made on one verify on the others.
  signingKeys = {
    tortuga = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIBtZzyKWyRf5LaFd8Oqrz0i3cygA0iNNsSOe5ZrL4M6xAAAAD3NzaDpnaXQtc2lnbmluZw==";
    framework = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOt6XQss7WQBbs/2gZtkzM1Jk07QfCUd+0+xdAlJQ0YSAAAAD3NzaDpnaXQtc2lnbmluZw==";
  };
in
{
  programs.git = {
    signing = {
      format = "ssh";
      key = "${config.home.homeDirectory}/.ssh/id_ed25519_sk_signing";
      signByDefault = true;
    };
    settings.gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
  };

  home.file.".ssh/allowed_signers".text = builtins.concatStringsSep "" (
    map (key: ''
      ${config.programs.git.settings.user.email} namespaces="git" ${key}
    '') (builtins.attrValues signingKeys)
  );
}
