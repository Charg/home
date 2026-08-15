# technitium-dnsserver

[Technitium DNS Server](https://github.com/TechnitiumSoftware/DnsServer) — recursive
resolver, authoritative nameserver, DHCP server and network-wide ad/tracker blocker in
one binary. Deployed via the community Helm chart
(`https://charts.obeone.cloud/technitium-dnsserver`), which wraps k8s-at-home's `common`
library chart.

Purpose here: become the LAN's DNS resolver, handed out by the UDM over DHCP, filtering
ads/trackers for every device on the network via blocklists rather than per-device
extensions.

## Exposure

`service.main` is a MetalLB `LoadBalancer` pinned to `192.168.74.21`
(`metallb.io/loadBalancerIPs` — pinned because it's a dynamic MetalLB allocation by
default, and once the UDM hands this address out as the network's DNS server, a service
recreation landing on a different IP is a silent, total DNS outage). Serves DNS on both
UDP and TCP 53 on that one VIP, plus the web console on 80/443. DHCP (67/UDP) is
explicitly disabled — the UDM is the DHCP server, and leaving 67 open on a LAN-facing VIP
is a rogue-DHCP hazard for no benefit.

## Persistence

`persistence.config` is a 10Gi `local-path` PVC mounted at `/etc/dns`. Deliberately
**not** `synology-iscsi-storage`: an iSCSI-backed PVC means the pod can't start while the
Synology is rebooting, and DNS being down takes the whole LAN with it. Node-local storage
removes that dependency (acceptable tradeoff on this single-node cluster).

`controller.strategy: Recreate` is required alongside `local-path` — it's hostPath-backed,
so a RollingUpdate would let old and new pods mount the same config directory on the same
node simultaneously, risking concurrent writes to `dns.config`.

## `DNS_SERVER_*` env vars are a first-boot bootstrap, not a declarative config

The `env` block in `values.yaml` (blocking, blocklist URLs, recursion mode, domain) is
only read by Technitium **when `/etc/dns/dns.config` does not yet exist** — i.e. once, on
a fresh PVC. After first boot, the web UI/API is authoritative and these values become
inert. Editing a blocklist URL in git after the initial rollout will do nothing; make
that change in the console (Settings → Blocked Zone / Block List) instead.

Currently seeded:
- **Recursion**: `AllowOnlyForPrivateNetworks` (covers `192.168.0.0/16`), no
  `DNS_SERVER_FORWARDERS` set — full recursive resolution against the root servers rather
  than forwarding to a third party, so no external resolver sees the LAN's query stream.
- **Blocklists**: [StevenBlack unified hosts](https://github.com/StevenBlack/hosts)
  (ads + malware) and [OISD Small](https://oisd.nl/) — a balanced, low-false-positive
  combination safe to hand to every device on the network without an allowlist.
