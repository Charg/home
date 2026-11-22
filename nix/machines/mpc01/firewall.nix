{ ... }:

{
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # Tailnet subnet router (kube/nuc01/tailscale-router)
  networking.firewall.allowedUDPPorts = [ 41642 ];
}
