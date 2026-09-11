{ pkgs, ... }:

{
  environment.localBinInPath = true;
  programs.zsh.enable = true;

  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_29;

  users.users.dev = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../../common/keys/home.pub)
    ];
  };
}
