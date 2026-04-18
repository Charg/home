{
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
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
    Welcome to NUC01!
  '';

  security.sudo.wheelNeedsPassword = false;
  nixpkgs.config.allowUnfree = true;
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

  networking.hostName = "nuc01";
}
