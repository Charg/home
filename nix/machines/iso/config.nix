# Create a NixOS ISO image
{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    efibootmgr
    git
    gptfdisk
    parted
    vim
  ];

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../../common/keys/home.pub)
    ];
  };

  security.sudo.wheelNeedsPassword = false;
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  services.openssh.enable = true;
  system.stateVersion = "23.11";
}
