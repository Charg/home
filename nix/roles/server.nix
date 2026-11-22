# Every headless host: an SSH-only admin account named after host.user.
{ host, lib, ... }:
{
  imports = [
    ./base.nix
    ../common/openssh-hardening.nix
  ];

  networking.hostName = host.name;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  users.users.${host.user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../common/keys/home.pub)
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  users.motd = ''
    Welcome to ${lib.toUpper host.name}!
  '';

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  boot.loader.grub = {
    devices = [ "nodev" ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
}
