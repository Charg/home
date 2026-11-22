# NixOS under WSL on a Windows machine.
{ pkgs, host, ... }:
{
  imports = [
    ../common/nix-ld.nix
    ../common/system-packages.nix # also via base; listed for its position
    ../common/ca-blacklist.nix
    ./base.nix
  ];

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = host.user;
    startMenuLaunchers = true;
  };

  # https://nix-community.github.io/NixOS-WSL/how-to/vscode.html#option-1-set-up-nix-ld
  programs.nix-ld.enable = true;

  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29;
  };

  users.extraGroups.docker.members = [ host.user ];

  # No sshd here, so sops-nix cannot derive an age identity from a host key.
  # Bootstrap once with `sudo age-keygen -o /var/lib/sops-nix/key.txt`, add the
  # printed public key as a recipient in .sops.yaml, create
  # nix/machines/<host>/secrets/users.enc.yaml, then import
  # ../common/sops-user-password.nix. Until then the existing shadow entry
  # is kept (users.mutableUsers defaults to true).
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };
}
