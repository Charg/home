{ config, ... }:

let
  nodeIP = (import ../../common/k3s-nodes.nix).${config.networking.hostName};
in

{
  users.users.nixos = {
    isNormalUser = true;
    hashedPassword = "$6$LsYSVIubO9ddl8lB$zGowqj8q0YLJZpGpKPjCf5wIDE6AnoOvOdPZIpiP213Dus0niljEDMQz0TJX3COGc70q2OHnZ.nut824iNiRo.";
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
    ];
  };

}
