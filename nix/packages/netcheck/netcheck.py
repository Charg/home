"""Detect RFC1918/RFC2544 address collisions between the current uplink and
local virtual networks (Docker, Podman, VirtualBox, minikube, ...).

In-flight and hotel Wi-Fi hand out DHCP leases from the same private ranges
that container/VM tooling carves up locally. When they overlap, traffic meant
for the real gateway gets routed into a local bridge instead and the
connection silently half-works.
"""

import argparse
import ipaddress
import json
import shutil
import subprocess
import sys

VIRTUAL_PREFIXES = ("docker", "br-", "veth", "vboxnet", "virbr", "podman", "cni-")
VPN_PREFIXES = ("wg", "tun")


def run_json(cmd):
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    return json.loads(out) if out.strip() else []


def is_virtual(ifname):
    return ifname.startswith(VIRTUAL_PREFIXES)


def is_vpn(ifname):
    return ifname.startswith(VPN_PREFIXES)


def route_network(route):
    dst = route.get("dst")
    if dst is None or dst == "default":
        return None
    try:
        return ipaddress.ip_network(dst, strict=False)
    except ValueError:
        return None


def classify_routes(routes):
    """Split routes into the real uplink (including VPNs and DHCP-pushed
    classless static routes) versus local virtual bridges/interfaces."""
    uplink = {}
    local = {}
    default_gateways = []

    for route in routes:
        ifname = route.get("dev")
        if not ifname:
            continue

        if route.get("dst") == "default":
            gw = route.get("gateway")
            if gw:
                default_gateways.append((ifname, gw))
            continue

        net = route_network(route)
        if net is None:
            continue

        bucket = local if is_virtual(ifname) else uplink
        bucket.setdefault(ifname, set()).add(net)

    return uplink, local, default_gateways


def docker_networks():
    """Map bridge interface name -> owning compose project (or network name)."""
    if shutil.which("docker") is None:
        return {}

    try:
        listing = subprocess.run(
            ["docker", "network", "ls", "--format", "{{json .}}"],
            capture_output=True,
            text=True,
            check=True,
            timeout=5,
        ).stdout
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
        return {}

    mapping = {}
    for line in listing.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            net = json.loads(line)
        except json.JSONDecodeError:
            continue

        net_id = net.get("ID")
        name = net.get("Name")
        if not net_id:
            continue

        try:
            inspect_out = subprocess.run(
                ["docker", "network", "inspect", net_id],
                capture_output=True,
                text=True,
                check=True,
                timeout=5,
            ).stdout
            details = json.loads(inspect_out)[0]
        except (
            subprocess.CalledProcessError,
            subprocess.TimeoutExpired,
            OSError,
            json.JSONDecodeError,
            IndexError,
        ):
            continue

        bridge_name = details.get("Options", {}).get("com.docker.network.bridge.name")
        if not bridge_name:
            bridge_name = "docker0" if name == "bridge" else f"br-{net_id[:12]}"

        project = details.get("Labels", {}).get("com.docker.compose.project")
        mapping[bridge_name] = project or name

    return mapping


def build_report():
    routes = run_json(["ip", "-j", "-4", "route"])
    uplink, local, gateways = classify_routes(routes)
    owners = docker_networks()

    conflicts = []
    for up_if, up_nets in uplink.items():
        for up_net in up_nets:
            for local_if, local_nets in local.items():
                for local_net in local_nets:
                    if up_net.overlaps(local_net):
                        conflicts.append(
                            {
                                "uplink_interface": up_if,
                                "uplink_subnet": str(up_net),
                                "local_interface": local_if,
                                "local_subnet": str(local_net),
                                "owner": owners.get(local_if, "unknown"),
                            }
                        )

    fatal = []
    for gw_if, gw in gateways:
        gw_addr = ipaddress.ip_address(gw)
        for local_if, local_nets in local.items():
            for local_net in local_nets:
                if gw_addr in local_net:
                    fatal.append(
                        {
                            "gateway_interface": gw_if,
                            "gateway": gw,
                            "local_interface": local_if,
                            "local_subnet": str(local_net),
                            "owner": owners.get(local_if, "unknown"),
                        }
                    )

    return {"conflicts": conflicts, "fatal": fatal}


def print_table(report):
    if report["fatal"]:
        print("FATAL - default gateway is inside a local virtual subnet:")
        for c in report["fatal"]:
            print(
                f"  {c['gateway']} (via {c['gateway_interface']}) is inside "
                f"{c['local_subnet']} on {c['local_interface']} (owner: {c['owner']})"
            )
    if report["conflicts"]:
        print("Overlapping subnets:")
        for c in report["conflicts"]:
            print(
                f"  {c['uplink_subnet']} on {c['uplink_interface']}  <->  "
                f"{c['local_subnet']} on {c['local_interface']} (owner: {c['owner']})"
            )


def print_suggestions(report):
    print("Suggested remediation:")
    for c in report["fatal"] + report["conflicts"]:
        owner = c["owner"]
        local_if = c["local_interface"]
        if owner != "unknown":
            print(f"  docker compose -p {owner} down    # frees {local_if}")
        else:
            print(f"  docker network rm {local_if}    # or identify the owning stack manually")
    print("  Then reconnect to this network so routes are recomputed.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    parser.add_argument(
        "--suggest", action="store_true", help="print remediation commands for detected conflicts"
    )
    args = parser.parse_args()

    report = build_report()
    has_conflict = bool(report["conflicts"] or report["fatal"])

    if args.json:
        print(json.dumps(report, indent=2))
    elif not has_conflict:
        print("netcheck: no overlap between uplink and local virtual networks")
    else:
        print_table(report)
        if args.suggest:
            print_suggestions(report)

    sys.exit(1 if has_conflict else 0)


if __name__ == "__main__":
    main()
