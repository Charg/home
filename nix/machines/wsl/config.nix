{ pkgs, currentSystemUser, ... }:
{
  imports = [
    ../../common/nix-ld.nix
    ../../common/system-packages.nix
    ../../common/ca-blacklist.nix
  ];

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = currentSystemUser;
    startMenuLaunchers = true;
  };

  environment.systemPackages = [
    pkgs.wget
  ];

  # https://nix-community.github.io/NixOS-WSL/how-to/vscode.html#option-1-set-up-nix-ld
  programs.nix-ld.enable = true;

  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29;
  };

  users.extraGroups.docker.members = [ currentSystemUser ];

  # No sshd here, so sops-nix cannot derive an age identity from a host key.
  # Bootstrap once with `sudo age-keygen -o /var/lib/sops-nix/key.txt`, add the
  # printed public key as a recipient in .sops.yaml, create
  # nix/machines/wsl/secrets/users.enc.yaml, then import
  # ../../common/sops-user-password.nix. Until then the existing shadow entry
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

  system.stateVersion = "24.11";
}
