# prowlarr

[Prowlarr](https://github.com/Prowlarr/Prowlarr), a Torznab/Newznab indexer
manager. It owns tracker definitions and login flows and re-exposes each
configured tracker as a uniform Torznab feed for Scryer to pull. Plain
manifests; there is no maintained upstream Helm chart.

Served at `https://prowlarr.home.packet.fail` on `traefik-internal`.

## Image

`ghcr.io/home-operations/prowlarr`: rootless, `catatonit` as PID 1, cosign
signed, and no s6-overlay boot hooks. Runs as uid/gid `1000` with all
capabilities dropped. Bump tag and digest together.

## Storage

`/config` holds `prowlarr.db`, an SQLite file, so the Deployment is
`replicas: 1` with `strategy: Recreate`. It sits on `local-path`, a node-local
PVC: SQLite fsyncs every write, and a network block device puts a round trip
behind each one. The cost is that the pod is pinned to whichever node first
bound the volume, and the volume can't move or be expanded. Prowlarr's own
backups (System → Backup) are the recovery path.

## API key is git-authoritative

`prowlarr-api-key.enc.yaml` sets `PROWLARR__AUTH__APIKEY`, so the key survives
a `/config` rebuild. Every Torznab URL configured in Scryer embeds it; a
regenerated key would break all of them at once. It can't be changed from the
UI.

## Routed through the WireGuard gateway

The pod template carries `setGateway: "true"`, so indexer calls and tracker
logins leave through the tunnel. The mechanism and its traps are in
`kube/nuc01/media-config/README.md`. Specific to Prowlarr:

- The injected `gateway-init` and `gateway-sidecar` run as root with
  `NET_ADMIN`/`NET_RAW`. Prowlarr's own container is unchanged, but the pod as
  a whole is weaker. That is inherent to building a VXLAN, and a deliberate
  trade.
- Never expose it to public clients (public Traefik, or
  `externalTrafficPolicy: Local`): replies to public addresses go down the
  tunnel and are dropped.
- Some private trackers refuse logins from VPN exits. Record any here by name.

`networkpolicy.yaml` allows ingress from `traefik-internal`, Scryer and the
gateway pod (required for VXLAN return traffic), and egress to kube-dns, Trawl,
bitmagnet's Torznab feed and the gateway. No internet rules: that traffic is inside the tunnel, where
an `ipBlock` rule can't see it.

## Configuration (manual)

1. Restore a Prowlarr backup (System → Backup → Restore), or on a fresh
   install set an admin username/password.
2. Settings → Indexers → Indexer Proxies → **FlareSolverr**, host
   `http://trawl.media.svc.cluster.local:8191`. Tag it and apply the tag to
   indexers behind a challenge.
3. Add trackers under Indexers and **Test** each.
4. In Scryer, add each indexer as a `torznab` source at
   `http://prowlarr.media.svc.cluster.local:9696/<indexerid>/api` with the key
   from the `prowlarr-api-key` secret.

Settings → Apps push-sync only targets *arr-family apps; Scryer pulls the feeds.
