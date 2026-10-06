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
}
