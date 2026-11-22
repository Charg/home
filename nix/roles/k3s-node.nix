# Members of the k3s cluster: etcd servers on LUKS disks unlocked over initrd
# SSH, with iSCSI and Longhorn storage.
{
  config,
  host,
  lib,
  modulesPath,
  pkgs,
  ...
}:

let
  nodeIP = config.lab.servers.${config.networking.hostName}.ipv4;

  # Initialised the cluster; every other node joins it.
  initNode = "nuc01";
in
{
  # Order follows the per-host configs this role replaced; module order sets
  # list-merge order, so changing it reorders packages and firewall rules.
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./k3s-node-disk.nix
    ../common/node-dns.nix
    ../common/lab-ipv6.nix
    ../common/k3s-firewall.nix
    ../common/system-packages.nix # also via base; listed for its position
    ../common/ca-blacklist.nix
    ../common/synology-iscsi.nix
    ../common/longhorn.nix
    ../common/initrd-ssh-unlock.nix
    ../common/fleetd.nix
    ../common/sops-user-password.nix
    ./server.nix
  ];

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
  ];

  # Increase maximum socket receive/send buffer sizes to 8MB
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 8388608;
    "net.core.wmem_max" = 8388608;
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
  }
  // (
    if host.name == initNode then
      { clusterInit = true; }
    else
      {
        serverAddr = "https://${initNode}:6443";
        tokenFile = "/etc/rancher/k3s/token";
      }
  );
}
