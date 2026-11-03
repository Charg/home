{ ... }:

# Docker's NAT rules route published ports around the NixOS firewall, and the
# daemon's "ip" default only covers docker0, not compose networks. Drop new
# forwarded connections into any Docker bridge unless they come from another
# one; the host itself still reaches published ports via localhost.
#
# mangle FORWARD runs ahead of the filter chains that k3s, Tailscale and Docker
# insert themselves into.
{
  networking.firewall.extraCommands = ''
    ip46tables -w -t mangle -D FORWARD -j docker-local-ports 2>/dev/null || true
    ip46tables -w -t mangle -F docker-local-ports 2>/dev/null || ip46tables -w -t mangle -N docker-local-ports
    ip46tables -w -t mangle -A docker-local-ports -i docker0 -j RETURN
    ip46tables -w -t mangle -A docker-local-ports -i br-+ -j RETURN
    ip46tables -w -t mangle -A docker-local-ports -o docker0 -m conntrack --ctstate NEW -j DROP
    ip46tables -w -t mangle -A docker-local-ports -o br-+ -m conntrack --ctstate NEW -j DROP
    ip46tables -w -t mangle -I FORWARD -j docker-local-ports
  '';

  networking.firewall.extraStopCommands = ''
    ip46tables -w -t mangle -D FORWARD -j docker-local-ports 2>/dev/null || true
    ip46tables -w -t mangle -F docker-local-ports 2>/dev/null || true
    ip46tables -w -t mangle -X docker-local-ports 2>/dev/null || true
  '';
}
