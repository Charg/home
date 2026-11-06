{ ... }:

{
  imports = [
    ../../common/k3s-firewall.nix
  ];

  networking.firewall.allowedTCPPorts = [
    22
    80
    443
  ];

  # Tailnet subnet router (kube/nuc01/tailscale-router)
  networking.firewall.allowedUDPPorts = [ 41642 ];
}
