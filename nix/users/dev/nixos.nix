{ pkgs, ... }:

{
  environment.localBinInPath = true;
  programs.zsh.enable = true;

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
