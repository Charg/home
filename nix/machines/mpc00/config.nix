{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../users/dev/nixos.nix
    ./firewall.nix
    ../../common/nix-ld.nix
    { home-manager.users.dev.home.stateVersion = "25.11"; }
  ];

  home-manager.users.dev = ../../users/dev/home-manager.nix;
}
