{ pkgs, currentSystemUser, ... }:
{
  imports = [ ../../common/nix-ld.nix ];

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = currentSystemUser;
    startMenuLaunchers = true;
  };

  environment.systemPackages = [
    pkgs.wget
  ];

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
