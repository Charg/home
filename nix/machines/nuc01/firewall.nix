{ ... }:

{
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
    6443 # k3s
  ];
}
