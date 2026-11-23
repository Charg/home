# DNS always goes to the LAN resolvers: directly at home, through the tailnet
# subnet routes elsewhere. The uplink's own DNS is ignored unless `netmode dns
# local` is used. See `netmode help`.
{
  config,
  lib,
  pkgs,
  host,
  ...
}:

let
  # "Home" is a known Wi-Fi SSID or default-gateway MAC, one per line in
  # secrets/netmode.enc.yaml (keys: ssids, gateways).
  homeSecret = key: {
    sopsFile = host.secretsFile "netmode";
    inherit key;
    group = "wheel";
    mode = "0440";
  };
  tunnelRoute = "192.168.74.0/24";
  resolvers = [
    "192.168.74.52"
    "192.168.74.53"
    "192.168.74.54"
  ];

  netmode = pkgs.writeShellApplication {
    name = "netmode";
    runtimeInputs = [
      config.services.tailscale.package
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.iproute2
      pkgs.iputils
      pkgs.jq
      pkgs.networkmanager
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      ROUTE="${tunnelRoute}"
      METRIC=10000
      STATE=/run/netmode/local
      SSIDS="${config.sops.secrets.netmode-home-ssids.path}"
      GATEWAYS="${config.sops.secrets.netmode-home-gateways.path}"
      HOME_VIA=""

      usage() {
        cat <<'EOF'
      Usage: netmode <command>

        status              Location, tunnel, DNS mode, guard, and a lookup test
        dns local           Use this network's DNS servers (captive portal, or the
                            tunnel won't come up). Undone on the next network change
        dns secure          Back to the LAN resolvers
        tunnel up|down      Start/stop tailscaled (down lasts until up or reboot)
        guard on|off        Blackhole the tunnel route when the tunnel is down, so
                            DNS can't leak to the local network. Automatic: on away
                            from home, off at home; re-applied on network change
        apply               Re-apply the automatic policy (run by NetworkManager)
      EOF
      }

      log() { logger -t netmode "$*"; echo "$*"; }

      as_root() {
        if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi
      }

      active_ssids() {
        local uuid
        nmcli -t -f UUID,TYPE connection show --active 2>/dev/null \
          | awk -F: '$2 == "802-11-wireless" {print $1}' \
          | while read -r uuid; do
            nmcli -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null | sed 's/\\:/:/g'
          done
      }

      gateway_macs() {
        local gw dev
        ip -4 -o route show default \
          | awk '{for (i = 1; i < NF; i++) {if ($i == "via") g = $(i + 1); if ($i == "dev") d = $(i + 1)} print g, d}' \
          | while read -r gw dev; do
            # Make sure the neighbour entry exists right after link-up
            ping -c1 -W1 -I "$dev" "$gw" >/dev/null 2>&1 || true
            ip neigh show "$gw" dev "$dev" \
              | awk '{for (i = 1; i < NF; i++) if ($i == "lladdr") print tolower($(i + 1))}'
          done
      }

      matches() { [ -r "$2" ] && [ -n "$1" ] && grep -Fxqi -- "$1" "$2"; }

      at_home() {
        local v
        while read -r v; do
          if matches "$v" "$SSIDS"; then HOME_VIA=wifi; return 0; fi
        done < <(active_ssids)
        while read -r v; do
          if matches "$v" "$GATEWAYS"; then HOME_VIA=gateway; return 0; fi
        done < <(gateway_macs)
        return 1
      }

      uplinks() {
        ip -o route show default | awk '{for (i = 1; i < NF; i++) if ($i == "dev") print $(i + 1)}' \
          | grep -v '^tailscale' | sort -u
      }

      con_uuid() { nmcli -g GENERAL.CON-UUID device show "$1" 2>/dev/null || true; }

      uplink_dns() {
        nmcli -g IP4.DNS,IP6.DNS device show "$1" 2>/dev/null \
          | tr '|' '\n' | sed -e 's/[[:space:]]//g' -e 's/\\//g' | grep -v -e '^$' -e '^fe80' || true
      }

      guard_is_on() { [ -n "$(ip route show exact "$ROUTE" type blackhole)" ]; }
      guard_on() { ip route replace blackhole "$ROUTE" metric "$METRIC"; }
      guard_off() { ip route del blackhole "$ROUTE" metric "$METRIC" 2>/dev/null || true; }

      dns_local() {
        mkdir -p "$(dirname "$STATE")"
        : >"$STATE"
        local dev
        for dev in $(uplinks); do
          mapfile -t servers < <(uplink_dns "$dev")
          if [ "''${#servers[@]}" -eq 0 ]; then
            echo "$dev: network provided no DNS servers, skipping" >&2
            continue
          fi
          resolvectl dns "$dev" "''${servers[@]}"
          resolvectl domain "$dev" '~.'
          resolvectl default-route "$dev" yes
          echo "$dev $(con_uuid "$dev")" >>"$STATE"
          log "dns local on $dev: ''${servers[*]}"
        done
        [ -s "$STATE" ] || { rm -f "$STATE"; echo "no uplink with DNS servers found" >&2; exit 1; }
      }

      dns_secure() {
        local dev
        for dev in $( { [ -f "$STATE" ] && awk '{print $1}' "$STATE"; uplinks; } | sort -u); do
          resolvectl revert "$dev" 2>/dev/null || true
        done
        rm -f "$STATE"
        log "dns secure"
      }

      # Drop local DNS for any device whose connection has changed since
      # `dns local`, so it never carries over to another network.
      expire_local() {
        [ -f "$STATE" ] || return 0
        local dev uuid keep=""
        while read -r dev uuid; do
          if [ -n "$uuid" ] && [ "$(con_uuid "$dev")" = "$uuid" ]; then
            keep+="$dev $uuid"$'\n'
          else
            resolvectl revert "$dev" 2>/dev/null || true
            log "dns local expired on $dev"
          fi
        done <"$STATE"
        if [ -n "$keep" ]; then printf '%s' "$keep" >"$STATE"; else rm -f "$STATE"; fi
      }

      apply() {
        if at_home; then
          tailscale set --accept-routes=false 2>/dev/null || true
          guard_off
          log "apply: home (routes off, guard off)"
        else
          tailscale set --accept-routes=true 2>/dev/null || true
          guard_on
          log "apply: away (routes on, guard on)"
        fi
        expire_local
      }

      status() {
        local location tunnel router routes dns
        if at_home; then location="home (matched $HOME_VIA)"; else location=away; fi
        [ -r "$SSIDS" ] || location+=" [home list unreadable]"
        if systemctl is-active -q tailscaled; then
          tunnel=$(tailscale status --json 2>/dev/null | jq -r '.BackendState' || echo unknown)
          router=$(tailscale status --json 2>/dev/null \
            | jq -r --arg r "$ROUTE" '[.Peer[]? | select((.PrimaryRoutes // []) | index($r)) | .Online] | if any then "online" else "offline" end' \
            || echo unknown)
          routes=$(tailscale debug prefs 2>/dev/null | jq -r 'if .RouteAll then "on" else "off" end' || echo unknown)
        else
          tunnel=stopped router=- routes=-
        fi
        if [ -f "$STATE" ]; then
          dns="local ($(awk '{print $1}' "$STATE" | paste -sd, -))"
        else
          dns="secure (${lib.concatStringsSep ", " resolvers})"
        fi

        printf '%-10s %s\n' location "$location"
        printf '%-10s %s (subnet router %s, accept-routes %s)\n' tunnel "$tunnel" "$router" "$routes"
        printf '%-10s %s\n' dns "$dns"
        printf '%-10s %s\n' guard "$(guard_is_on && echo on || echo off)"
        if timeout 4 resolvectl query --cache=no -t A example.com >/dev/null 2>&1; then
          printf '%-10s %s\n' lookup ok
        else
          printf '%-10s %s\n' lookup FAILED
        fi
      }

      case "''${1:-status}" in
        status) status ;;
        apply) as_root "$@"; apply ;;
        dns)
          case "''${2:-}" in
            local) as_root "$@"; dns_local ;;
            secure) as_root "$@"; dns_secure ;;
            *) usage; exit 1 ;;
          esac
          ;;
        tunnel)
          case "''${2:-}" in
            up) as_root "$@"; systemctl start tailscaled; log "tunnel up" ;;
            down) as_root "$@"; systemctl stop tailscaled; log "tunnel down" ;;
            *) usage; exit 1 ;;
          esac
          ;;
        guard)
          case "''${2:-}" in
            on) as_root "$@"; guard_on; log "guard on" ;;
            off) as_root "$@"; guard_off; log "guard off" ;;
            *) usage; exit 1 ;;
          esac
          ;;
        help | -h | --help) usage ;;
        *) usage; exit 1 ;;
      esac
    '';
  };

  dispatcher = pkgs.writeShellScript "netmode-dispatcher" ''
    case "$2" in
      up | down | dhcp4-change | dhcp6-change)
        ${pkgs.systemd}/bin/systemctl restart --no-block netmode-apply.service
        ;;
    esac
  '';
in
{
  # The uplink's DNS servers are never used unless `netmode dns local`
  networking.networkmanager.dns = lib.mkForce "none";
  services.resolved.settings.Resolve = {
    DNS = resolvers;
    Domains = [ "~." ];
  };

  sops.secrets.netmode-home-ssids = homeSecret "ssids";
  sops.secrets.netmode-home-gateways = homeSecret "gateways";

  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = dispatcher;
    }
  ];

  # Also runs whenever tailscaled starts, so routes are set once it is up
  systemd.services.netmode-apply = {
    after = [ "tailscaled.service" ];
    wantedBy = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${netmode}/bin/netmode apply";
    };
  };

  environment.systemPackages = [ netmode ];
}
