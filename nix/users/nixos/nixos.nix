{ config, ... }:

let
  nodeIP = (import ../../common/k3s-nodes.nix).${config.networking.hostName};
in

{
  imports = [
    ../../common/node-dns.nix
  ];

  users.users.nixos = {
    isNormalUser = true;
  };

  services.k3s = {
    enable = true;
    role = "server";
    disable = [
      "traefik"
      "servicelb"
      "metrics-server"
    ];
    # Pin the node address; k3s never re-detects it after first registration.
    extraFlags = [
      "--node-ip=${nodeIP}"
      "--advertise-address=${nodeIP}"
      "--tls-san=${nodeIP}"
      "--etcd-expose-metrics"
      "--kubelet-arg=allowed-unsafe-sysctls=net.ipv4.conf.all.src_valid_mark"
    ];
  };

}
