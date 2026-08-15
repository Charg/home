# technitium-dnsserver

Second of a redundant pair with
[`kube/lookie/technitium-dnsserver`](../../lookie/technitium-dnsserver/README.md). That
one explains the chart, image, and general reasoning shared by both — this file only
covers what's specific to *this* copy.

## Why a second instance

The lookie instance is a single pod on a single-node cluster, about to become the whole
LAN's DNS resolver via UDM DHCP. That's a single point of failure for the entire network.
This instance is an independent twin on a separate physical host (`nuc01`), so the UDM can
hand out two resolvers and either box going down doesn't take DNS with it.

`/etc/dns/zones` on the lookie instance is empty — there are no authoritative zones to
replicate — so the two servers don't need any zone-transfer relationship. Each is a
standalone full-recursion resolver with the same blocklists, fetched independently.
**Deliberately not forwarding to lookie's `.21`** — that would just move the single point
of failure rather than remove it.

## Keeping the twins in sync

The `env` block here must be kept identical to lookie's (aside from `DNS_SERVER_DOMAIN`).
Like lookie's copy, it's a first-boot-only bootstrap — read once, when `/etc/dns/dns.config`
doesn't yet exist, then inert. Neither git nor the running server will warn you about
drift between the two, and there is no automatic sync: **a config change (e.g. a new
blocklist URL) must be made by hand in both web consoles**, not just committed here.

## Exposure

`service.main` is a MetalLB `LoadBalancer` pinned to `192.168.74.52`
(`metallb.io/loadBalancerIPs`) — same reasoning as lookie's `.21` pin: once the UDM hands
this out as a DNS server, a service recreation landing on a different IP is a silent DNS
outage. nuc01's MetalLB pool is `192.168.74.50-192.168.74.69`
(`kube/nuc01/metallb-config/ipaddresspool.yaml`); `.50` and `.51` are already taken by
`traefik-internal`/`traefik-public`, so `.52` is the next free address. DHCP (67/UDP) is
disabled for the same rogue-DHCP reason as lookie.

## Persistence

Same as lookie: a 10Gi `local-path` PVC at `/etc/dns`, `controller.strategy: Recreate`
required because `local-path` is hostPath-backed. nuc01's only StorageClass is
`local-path` (the cluster default), so there's no iSCSI-equivalent tradeoff to make here.

## Redundancy only takes effect once the UDM uses both

Deploying this instance alone does nothing for the LAN until the UDM's DHCP config hands
out **both** `192.168.74.21` and `192.168.74.52` as DNS servers. That's a manual, out-of-
repo change. Until then this instance runs and is reachable, but nothing queries it.

Note this gives failover, not load balancing: most stub resolvers try the first DNS
server and only fall back to the second on timeout (commonly 1-5s), so a lookie outage
reads as a brief hiccup on first lookup rather than being invisible.
