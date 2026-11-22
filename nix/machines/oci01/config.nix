{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./headscale.nix
    ./auto-upgrade.nix
    ./backup.nix
    ./nas-backup.nix
    ../../common/tailscale.nix
  ];

  # Same DHCP client as the nixos-anywhere installer
  networking.useNetworkd = true;

  # Nothing on this network to discover; the firewall drops these anyway
  services.resolved.settings.Resolve = {
    LLMNR = false;
    MulticastDNS = false;
  };
}
