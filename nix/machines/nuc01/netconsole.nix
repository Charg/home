{ pkgs, ... }:

let
  tortuga = (import ../../common/k3s-agents.nix).tortuga;
  port = 6666;
in
{
  # Receives tortuga's netconsole stream into the journal, which Alloy ships to Loki as
  # {host="nuc01", unit="netconsole-receiver.service"}. Each UDP packet is one
  # kernel message.
  systemd.services.netconsole-receiver = {
    description = "Receive kernel messages from tortuga over netconsole";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat -u UDP4-RECV:${toString port} STDOUT";
      SyslogIdentifier = "netconsole-tortuga";
      DynamicUser = true;
      Restart = "always";
    };
  };

  networking.firewall.extraCommands = ''
    iptables -w -A nixos-fw -p udp -s ${tortuga} --dport ${toString port} -j nixos-fw-accept
  '';
}
