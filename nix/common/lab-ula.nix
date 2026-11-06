# IPv6 ULA addressing for the lab network. Node addresses reuse the last octet
# of the node's IPv4 address.
let
  prefix = "fd89:69aa:94a4";
  lab = "${prefix}:74";
in
{
  inherit prefix;
  prefixLength = 48;
  gateway = "${lab}::1";
  nodeAddress = ip4: "${lab}::${builtins.elemAt (builtins.split "\\." ip4) 6}";
}
