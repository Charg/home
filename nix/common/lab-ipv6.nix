{ config, pkgs, ... }:

# A static ULA on the lab interface, used only to serve DNS (node-dns.nix) to
# IPv6 clients on other networks. The lab network sends no router
# advertisements, so nodes get no IPv6 default route: anything trying IPv6
# off-link without binding the ULA fails at once and falls back to IPv4.
# Traffic from the ULA (CoreDNS) is the one exception, routed through its own
# table.

let
  ula = import ./lab-ula.nix;
  nodeIP = (import ./k3s-nodes.nix).${config.networking.hostName};
  address = ula.nodeAddress nodeIP;
  iface = "eno1";
  table = "53";
in
{
  networking.interfaces.${iface}.ipv6 = {
    addresses = [
      {
        inherit address;
        prefixLength = 64;
      }
    ];
    routes = [
      {
        address = "${ula.prefix}::";
        prefixLength = ula.prefixLength;
        via = ula.gateway;
      }
    ];
  };

  # Ignore router advertisements and DHCPv6 even if the lab network starts
  # sending them.
  networking.dhcpcd.extraConfig = ''
    noipv6rs
    noipv6
  '';
  boot.kernel.sysctl."net.ipv6.conf.${iface}.accept_ra" = 0;

  # Let CoreDNS bind the address while it's still tentative (duplicate
  # address detection) at boot.
  boot.kernel.sysctl."net.ipv6.ip_nonlocal_bind" = 1;

  # Matches on source address only: the reverse path filter checks this
  # route for incoming queries, and its lookup carries no ports.
  systemd.services.lab-ipv6-ula-route = {
    description = "Route traffic from the lab ULA via the lab gateway";
    after = [ "network-addresses-${iface}.service" ];
    requires = [ "network-addresses-${iface}.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.iproute2 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ip -6 route replace default via ${ula.gateway} dev ${iface} table ${table}
      ip -6 rule del from ${address} lookup ${table} 2>/dev/null || true
      ip -6 rule add from ${address} lookup ${table}
    '';
    preStop = ''
      ip -6 rule del from ${address} lookup ${table} || true
      ip -6 route flush table ${table} || true
    '';
  };

  networking.firewall.extraCommands = ''
    ip6tables -w -A nixos-fw -p udp -d ${address} --dport 53 -j nixos-fw-accept
    ip6tables -w -A nixos-fw -p tcp -d ${address} --dport 53 -j nixos-fw-accept
  '';
}
