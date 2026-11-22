# The lab network's k3s nodes, declared once and type-checked. Modules read
# them from `config.lab`.
{ config, lib, ... }:

let
  inherit (lib) mkOption types;

  ipv4 = types.strMatching "([0-9]{1,3}\\.){3}[0-9]{1,3}";

  node = types.submodule (
    { config, ... }:
    {
      options = {
        ipv4 = mkOption {
          type = ipv4;
          description = "The node's pinned lab IPv4 address.";
        };
        ipv6 = mkOption {
          type = types.str;
          readOnly = true;
          description = "The node's ULA, reusing the last octet of its IPv4 address.";
        };
      };
      config.ipv6 = "${ula.lab}::${lib.last (lib.splitString "." config.ipv4)}";
    }
  );

  ula = config.lab.ula;
in
{
  options.lab = {
    servers = mkOption {
      type = types.attrsOf node;
      description = "k3s servers (etcd members), by hostname.";
    };

    agents = mkOption {
      type = types.attrsOf node;
      description = "Worker-only k3s nodes, by hostname. They may be offline at any time, so they never join etcd.";
    };

    ula = {
      prefix = mkOption {
        type = types.str;
        description = "The lab's IPv6 ULA prefix.";
      };
      prefixLength = mkOption {
        type = types.ints.between 0 128;
        description = "Length of the ULA prefix.";
      };
      lab = mkOption {
        type = types.str;
        readOnly = true;
        default = "${ula.prefix}:74";
        description = "The lab network's /64 within the ULA prefix.";
      };
      gateway = mkOption {
        type = types.str;
        readOnly = true;
        default = "${ula.lab}::1";
        description = "The lab network's IPv6 gateway.";
      };
    };
  };

  config.lab = {
    servers = {
      nuc01.ipv4 = "192.168.74.120";
      mpc00.ipv4 = "192.168.74.11";
      mpc01.ipv4 = "192.168.74.12";
    };

    agents = {
      tortuga.ipv4 = "192.168.73.9";
    };

    ula = {
      prefix = "fd89:69aa:94a4";
      prefixLength = 48;
    };
  };
}
