{ config, lib, ... }:

let
  nodes = {
    nuc01 = "192.168.74.120";
    mpc00 = "192.168.74.11";
    mpc01 = "192.168.74.12";
  };

  peers = lib.attrValues (lib.filterAttrs (name: _: name != config.networking.hostName) nodes);

  peerTcpPorts = [
    2379 # etcd client
    2380 # etcd peer
    10250 # kubelet API
    7946 # metallb memberlist
    9100 # node-exporter
  ];
  peerUdpPorts = [
    7946 # metallb memberlist
    8472 # flannel VXLAN
  ];

  peerRules = lib.concatMap (peer: [
    "iptables -w -A nixos-fw -p tcp -s ${peer} -m multiport --dports ${
      lib.concatMapStringsSep "," toString peerTcpPorts
    } -j nixos-fw-accept"
    "iptables -w -A nixos-fw -p udp -s ${peer} -m multiport --dports ${
      lib.concatMapStringsSep "," toString peerUdpPorts
    } -j nixos-fw-accept"
  ]) peers;
in
{
  assertions = [
    {
      assertion = nodes ? ${config.networking.hostName};
      message = "k3s-firewall: ${config.networking.hostName} is not listed in nodes";
    }
  ];

  networking.firewall.allowedTCPPorts = [
    6443 # k3s apiserver
  ];

  networking.firewall.extraCommands = lib.concatStringsSep "\n" peerRules + "\n";

  # Keep dhcpcd's IPv4LL addresses off CNI interfaces; a 169.254.x address on
  # flannel.1 becomes the source for host-to-remote-pod traffic, which can't return.
  networking.dhcpcd.denyInterfaces = [
    "cni*"
    "flannel*"
    "veth*"
  ];
}
