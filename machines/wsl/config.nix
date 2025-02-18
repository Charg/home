{ pkgs, currentSystemUser, ... }: {
  imports = [];

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
  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs; # only for NixOS 24.05
};

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
