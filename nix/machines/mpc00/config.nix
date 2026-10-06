{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../users/dev/nixos.nix
    ./firewall.nix
    ../../common/nix-ld.nix
    ../../common/system-packages.nix
    ../../common/synology-iscsi.nix
    ../../common/initrd-ssh-unlock.nix
  ];

  home-manager.users.dev = ../../users/dev/home-manager.nix;

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../../common/keys/home.pub)
    ];
  };

  users.motd = ''
    Welcome to MPC00!
  '';

  security.sudo.wheelNeedsPassword = false;
  nixpkgs.config.allowUnfree = true;

  # Join forces with the nuc01 cluster
  services.k3s.serverAddr = "https://nuc01:6443";
  services.k3s.tokenFile = "/etc/rancher/k3s/token";

  # Pin k3s's node address instead of relying on auto-detection: the node
  # registered with a stale, no-longer-valid address at first boot (before
  # the static DHCP reservation had taken effect) and k3s never re-detects
  # after initial registration.
  services.k3s.extraFlags = lib.mkForce "--disable=traefik --disable=servicelb --disable=metrics-server --node-ip=192.168.74.11 --advertise-address=192.168.74.11 --tls-san=192.168.74.11";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Increase maximum socket receive/send buffer sizes to 8MB
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 8388608;
    "net.core.wmem_max" = 8388608;
  };

  services.openssh.enable = true;
  system.stateVersion = "25.11";

  networking.hostName = "mpc00";
}
