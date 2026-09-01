# prowlarr

[Prowlarr](https://github.com/Prowlarr/Prowlarr) — a Torznab/Newznab indexer manager. No
official Helm chart exists (k8s-at-home's is archived, TrueCharts is TrueNAS-oriented), so
this is a plain-manifest app, same pattern as `kube/lookie/scryer/`,
`kube/lookie/qbittorrent/` and `kube/lookie/trawl/`.

Deployed so Scryer (`kube/lookie/scryer/`) stops holding tracker logins itself. Two of
Scryer's `torznab` indexers were returning HTML login/interstitial pages instead of caps
XML (see the "Unrelated, but noticed" note in the git history around the scryer 0.18.11
bump) — Prowlarr owns tracker definitions and login flows, and re-exposes every
configured tracker as a uniform Torznab feed.

## Image

`ghcr.io/home-operations/prowlarr`, not `lscr.io/linuxserver/prowlarr`. Chosen because it
runs rootless (`nobody:nogroup` in the upstream image; this Deployment pins a fixed
`1000:1000` via `securityContext`) with `catatonit` as PID 1, is smaller, ships with
cosign signatures/attestations, and has no `S6_STAGE2_HOOK` boot-time code-execution
mechanism the way s6-overlay-based images do. Pinned to `2.5.2.5491`, the latest
non-prerelease upstream release; bump deliberately, tag and digest together.

## No shared media volume

Unlike qBittorrent/Scryer/Plex, Prowlarr never touches media files — it only searches and
serves Torznab/Newznab feeds. It does **not** mount `plex-media`, and doesn't need
`PUID/PGID=0` or root — the container runs as uid/gid `1000` with
`allowPrivilegeEscalation: false` and all capabilities dropped.

## Storage

`prowlarr-config` PVC, 5Gi, `synology-iscsi-storage`, RWO, mounted at `/config` (holds
`prowlarr.db`, an SQLite file — same "must never have two writers" constraint as Scryer,
hence `strategy: Recreate` / `replicas: 1`).

## API key is git-authoritative

`prowlarr-api-key.enc.yaml` sets `PROWLARR__AUTH__APIKEY` so the key is fixed across
`/config` rebuilds. Prowlarr generates a random API key on first run if this env var
isn't set; a regenerated key would silently break every Torznab URL configured in Scryer
at once, since those URLs embed the key as a query param. It is not editable from the UI
once fixed this way.

## First-run configuration (manual, one-time)

1. Open `https://prowlarr.packet.fail` and set an admin username/password.
2. Settings → Indexers → **Indexer Proxies** → add a **FlareSolverr** proxy:
   - **Host**: `http://trawl.default.svc.cluster.local:8191`
   - Tag it (e.g. `flaresolverr`) and apply that tag to indexers that sit behind
     Cloudflare or similar challenges.

   Trawl (`kube/lookie/trawl/`) serves a FlareSolverr-compatible `POST /v1` API on 8191 —
   the same endpoint Scryer's own indexer-proxy setting already drives — so this is
   expected to work. Confirm with **Test** before relying on it.
3. Add trackers under Indexers, using **Test** on each.
4. For each indexer, note its numeric ID from its Torznab feed URL
   (`.../<indexerid>/api?apikey=...`), then add it into Scryer as a `torznab` indexer
   pointing at `http://prowlarr.default.svc.cluster.local:9696/<indexerid>/api` with the
   API key from the `prowlarr-api-key` secret. See `kube/lookie/scryer/README.md` step 5.

Prowlarr's push-sync (Settings → Apps) only targets *arr-family apps (Sonarr, Radarr,
etc.) — Scryer isn't in that catalog, so this pull/Torznab-feed direction is the only
integration path.

## Routed through the WireGuard gateway

`spec.template.metadata.labels` carries `setGateway: "true"`, so indexer API calls
and tracker logins leave through the tunnel rather than the house connection. The
mechanism, and every trap in it, is documented in
`kube/lookie/pod-gateway-config/README.md`. Three things specific to Prowlarr:

**The pod's security context is meaningfully weaker, and that is a conscious
trade.** The injected `gateway-init` and `gateway-sidecar` run **as root with
`NET_ADMIN` and `NET_RAW` and an empty capability drop list**. That is hard-coded
in the admission controller and is not configurable. Prowlarr's own container is
untouched — still uid 1000, `runAsNonRoot`, `drop: [ALL]`,
`allowPrivilegeEscalation: false` — but the pod as a whole now contains two root
containers with network capabilities. This is inherent to the mechanism: you
cannot build a VXLAN without `NET_ADMIN`. It is a trade, not a bug, but a security
review should find a decision here rather than an accident.

**Prowlarr can never be exposed with a public client address.** Inbound is
untouched, but once the default route is deleted a reply is only deliverable if
its destination matches one of the routes installed from
`NOT_ROUTED_TO_GATEWAY_CIDRS`. `traefik-internal` SNATs, so its pod address is in
the pod range and the flow stays symmetric; kubelet's probes come from the node or
the CNI bridge, both also in that list. But a *public* client address matches no
not-routed route, so the reply would go down the tunnel and be dropped as
asymmetric. Prowlarr must therefore never be moved behind the public Traefik
instance or a Service with `externalTrafficPolicy: Local`.

**Indexers that reject the VPN exit.** Some private trackers flag or refuse logins
from datacenter VPN addresses. That is a per-indexer policy problem, not something
to solve by changing the routing. None recorded so far; add any here by name as
they turn up.

`networkpolicy.yaml` includes the gateway **ingress** rule, which is load-bearing
rather than tidy — see the conntrack section of the gateway README. Scryer's pull
of the Torznab feeds is unaffected: that flow is in the pod range, which is in
`NOT_ROUTED_TO_GATEWAY_CIDRS`, so it travels the normal path.

## Secrets

- `prowlarr-tls` — cert-manager-issued, regenerates automatically.

`prowlarr-api-key` is in git, SOPS-encrypted, decrypted at sync time by lookie's Argo CD
CMP plugin (`kube/lookie/argocd/values.yaml`).
