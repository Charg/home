# trawl

[germondai/trawl](https://github.com/germondai/trawl), a self-hosted scraping
engine that solves JS challenges and CAPTCHAs. It serves a
FlareSolverr-compatible `POST /v1` on 8191, used by Scryer and Prowlarr as an
indexer proxy. Plain manifests; there is no upstream Helm chart.

Served at `https://trawl.home.packet.fail` on `traefik-internal`, for driving a
solve by hand.

## No `plugin: {}` on the Application

The SOPS CMP plugin is discovered by `**/*.enc.yaml`. Trawl has no secrets, so
forcing the plugin fails to resolve. Add `plugin: {}` back if a secret is ever
added here.

## Image

Each release has a plain tag (modern Bun runtime, needs AVX2 and kernel 5.1+)
and a `-baseline` tag for older CPUs. The plain tag is used. `:latest` tracks
`main`, not releases; bump tag and digest together.

## Redis sidecar and storage

Redis is a native sidecar (`restartPolicy: Always` init container) holding a
30-minute session cache on an `emptyDir`. Losing it costs fresh solves, nothing
more. No PVC.

The sidecar is gated by a `startupProbe`, not a readinessProbe: kubelet starts
the next container once a restartable init container's startupProbe passes, and
ignores readiness. Redis 8 takes ~1.5-2s to load its bundled modules, longer
than trawl's 1s startup connect timeout, and trawl never retries, so without the
gate the cache tier is disabled for the pod's lifetime. There is deliberately no
readinessProbe on the sidecar, since it would feed pod readiness and a Redis
blip would drop trawl from its Service.

`REDIS_URL` is unset; the default `redis://localhost:6379` is the sidecar.

`/dev/shm` is a 1Gi memory `emptyDir`, matching upstream's `shm_size: 1gb`.

## MITM proxy stays off

Trawl can also run a challenge-bypassing forward proxy on 8192
(`MITM_PROXY_ENABLED`). Neither caller uses it, so it is left at its default
(off).

## Routed through the WireGuard gateway

The pod template carries `setGateway: "true"`, so every page Trawl fetches
loads from the tunnel's exit. The mechanism and its traps are in
`kube/nuc01/media-config/README.md`. Specific to Trawl:

- **Init order matters.** The webhook appends `gateway-init` after `redis`, so
  Redis starts before the tunnel exists. That is fine only because Redis needs
  nothing beyond loopback. A future native sidecar that needs the internet
  would start before the route is in place; put it in `containers:` instead.
- **Watch the solve rate.** Challenge providers score VPN ranges more harshly
  than residential ones. When this was measured, five cache-busted solves
  against a live Cloudflare challenge succeeded 5/5 from both the house
  connection and the tunnel, at ~6s each. Re-measure before blaming the exit,
  and use a target that actually serves a challenge. Removing the label is the
  revert.
- The injected `gateway-init` and `gateway-sidecar` run as root with
  `NET_ADMIN`/`NET_RAW`. That is inherent to building a VXLAN, and a deliberate
  trade.
- Never expose it to public clients (public Traefik, or
  `externalTrafficPolicy: Local`): replies to public addresses go down the
  tunnel and are dropped.

`networkpolicy.yaml` allows ingress from `traefik-internal`, Scryer, Prowlarr
and the gateway pod (required for VXLAN return traffic), and egress to kube-dns
and the gateway. No internet rules: a scraper's destination set is every site
it is asked to fetch, and that traffic is inside the tunnel anyway. Redis is
loopback, which NetworkPolicy does not see.

## Configuration

None on Trawl itself. Callers point their FlareSolverr setting at
`http://trawl.media.svc.cluster.local:8191`.
