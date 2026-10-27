{ config, ... }:

# Technitium runs in this cluster, so after a cold boot (e.g. a power outage) it's down
# until its pods are back; 1.1.1.1 covers that window.

let
  nodeIP = (import ./k3s-nodes.nix).${config.networking.hostName};

  technitium = [
    "192.168.74.52"
    "192.168.74.53"
    "192.168.74.54"
  ];
  fallback = "1.1.1.1";

  # k3s's default cluster-cidr.
  podCIDR = "10.42.0.0/16";
in
{
  services.coredns = {
    enable = true;
    config = ''
      .:53 {
        bind 127.0.0.1 ${nodeIP}
        errors
        cache 30
        forward . ${toString technitium} ${fallback} {
          policy sequential
        }
      }
    '';
  };

  # Ignore DHCP-provided DNS; the node always asks its local resolver.
  networking.dhcpcd.extraConfig = ''
    nooption domain_name_servers, domain_name, domain_search
  '';
  networking.nameservers = [ "127.0.0.1" ];

  # kubelet can't hand pods 127.0.0.1 (that's the pod's own loopback), and if
  # /etc/resolv.conf is loopback-only k3s silently picks /run/systemd/resolve/resolv.conf
  # or 8.8.8.8 instead. Point it at the node IP explicitly.
  environment.etc."k3s-resolv.conf".text = ''
    nameserver ${nodeIP}
  '';
  services.k3s.extraFlags = [ "--kubelet-arg=resolv-conf=/etc/k3s-resolv.conf" ];

  networking.firewall.extraCommands = ''
    iptables -w -A nixos-fw -p udp -s ${podCIDR} -d ${nodeIP} --dport 53 -j nixos-fw-accept
    iptables -w -A nixos-fw -p tcp -s ${podCIDR} -d ${nodeIP} --dport 53 -j nixos-fw-accept
  '';
}
