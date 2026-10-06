{ lib, ... }:

let
  peers = [
    "192.168.74.120" # nuc01
    "192.168.74.11" # mpc00
  ];
  peerTcpPorts = [
    2379 # etcd client
    2380 # etcd peer
    10250 # kubelet API
    7946 # metallb memberlist
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
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
    6443 # k3s apiserver
  ];

  networking.firewall.extraCommands = lib.concatStringsSep "\n" peerRules + "\n";
}
