{ pkgs, ... }:

let
  nuc01 = (import ../../common/k3s-nodes.nix).nuc01;
  port = 6666;
in
{
  # Streams kernel messages over UDP to nuc01
  boot.kernelModules = [ "netconsole" ];

  # Set up through configfs rather than the module option, which needs the NIC
  # up with an address when the module loads. netconsole sends raw frames with
  # no routing or ARP, so the target MAC is the next hop: the gateway, since
  # nuc01 is on another subnet. The local address is taken from the NIC.
  systemd.services.netconsole = {
    description = "Send kernel messages to nuc01 over netconsole";
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "sys-kernel-config.mount"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.gawk
      pkgs.iproute2
      pkgs.iputils
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      read -r via dev < <(ip -4 route get ${nuc01} |
        awk '{ for (i = 1; i < NF; i++) { if ($i == "via") v = $(i + 1); if ($i == "dev") d = $(i + 1) } print (v ? v : "${nuc01}"), d; exit }')
      ping -c 1 -W 2 "$via" > /dev/null || true
      mac=$(ip neigh show "$via" dev "$dev" | awk '{ print $3; exit }')
      if [ -z "$mac" ]; then
        echo "no MAC for next hop $via on $dev" >&2
        exit 1
      fi

      target=/sys/kernel/config/netconsole/nuc01
      mkdir -p "$target"
      # Writing the current value back fails with EINVAL.
      if [ "$(cat "$target/enabled")" = 1 ]; then echo 0 > "$target/enabled"; fi
      echo "$dev" > "$target/dev_name"
      echo ${nuc01} > "$target/remote_ip"
      echo ${toString port} > "$target/remote_port"
      echo "$mac" > "$target/remote_mac"
      echo 1 > "$target/enabled"
      echo "netconsole to ${nuc01}:${toString port} via $via ($mac) on $dev"

      # The console loglevel (4) only lets errors through, so info-level
      # messages like "PM: suspend entry" would never be sent. Raised only
      # once booted, so boot output on the screen is unchanged; GNOME hides the
      # framebuffer console. Oopses and panics are always sent in full.
      echo 7 > /proc/sys/kernel/printk
    '';
    preStop = ''
      echo 4 > /proc/sys/kernel/printk
      target=/sys/kernel/config/netconsole/nuc01
      if [ "$(cat "$target/enabled")" = 1 ]; then echo 0 > "$target/enabled"; fi
      rmdir "$target"
    '';
  };
}
