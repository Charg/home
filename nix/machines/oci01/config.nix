{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./headscale.nix
    ./auto-upgrade.nix
    ./backup.nix
    ../../common/tailscale.nix
    ../../common/system-packages.nix
    ../../common/openssh-hardening.nix
  ];

  users.motd = ''
    Welcome to OCI01!
  '';

  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Same DHCP client as the nixos-anywhere installer
  networking.useNetworkd = true;

  # Nothing on this network to discover; the firewall drops these anyway
  services.resolved.settings.Resolve = {
    LLMNR = false;
    MulticastDNS = false;
  };

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "26.05";

  networking.hostName = "oci01";
}
