{ pkgs, currentSystemUser, ... }:
{
  imports = [
    ../../common/nix-ld.nix
    ../../common/system-packages.nix
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
