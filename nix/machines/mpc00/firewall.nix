{ lib, ... }:

let
  peers = [
    "192.168.74.120" # nuc01
    "192.168.74.12" # mpc01
  ];
  peerTcpPorts = [
    2379 # etcd client
    2380 # etcd peer
    10250 # kubelet API
  ];

  peerRules = lib.concatMap (peer: [
    "iptables -w -A nixos-fw -p tcp -s ${peer} -m multiport --dports ${
      lib.concatMapStringsSep "," toString peerTcpPorts
    } -j nixos-fw-accept"
    "iptables -w -A nixos-fw -p udp -s ${peer} --dport 8472 -j nixos-fw-accept" # flannel VXLAN
  ]) peers;
in
{
  networking.firewall.allowedTCPPorts = [
    22
    6443 # k3s apiserver

    # ac - dev containers - slot 0
    8010
    5173
    8026
    9010
    9011
    8020
    3010
    8088

    # ov - dev containers - slot 0
    8000
    8025
    9000
    9001
    8080
  ];

  # Dev containers
  networking.firewall.allowedTCPPortRanges = [
    {
      from = 20000;
      to = 29999;
    }
  ];

  networking.firewall.extraCommands = lib.concatStringsSep "\n" peerRules + "\n";
}
