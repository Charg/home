{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common/system-packages.nix
    ./firewall.nix
  ];

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../../common/keys/home.pub)
    ];
  };

  users.motd = ''
    Welcome to MPC01!
  '';

  security.sudo.wheelNeedsPassword = false;
  nixpkgs.config.allowUnfree = true;

  # Join forces with the nuc01 cluster
  services.k3s.serverAddr = "https://nuc01:6443";
  services.k3s.tokenFile = "/etc/rancher/k3s/token";
  services.k3s.extraFlags = lib.mkForce "--disable=traefik --disable=servicelb --disable=metrics-server --node-ip=192.168.74.12 --advertise-address=192.168.74.12 --tls-san=192.168.74.12";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Increase maximum socket receive/send buffer sizes to 8MB
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 8388608;
    "net.core.wmem_max" = 8388608;
  };

  boot.kernelParams = [ "ip=dhcp" ];
  boot.initrd.network.enable = true;
  boot.initrd.network.ssh = {
    enable = true;
    port = 2222;
    shell = "/bin/cryptsetup-askpass";
    authorizedKeys = [
      (builtins.readFile ../../common/keys/home.pub)
    ];
    hostKeys = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
  };

  services.openssh.enable = true;
  system.stateVersion = "25.11";

  networking.hostName = "mpc01";
}
