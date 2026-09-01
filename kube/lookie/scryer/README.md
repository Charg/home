# scryer

[scryer-media/scryer](https://github.com/scryer-media/scryer) — a Sonarr/Radarr-style
media manager. No upstream Helm chart exists, so this is a plain-manifest app (same
pattern as `kube/lookie/qbit-neo/` and `kube/nuc01/cloudflared/`).

Pre-1.0, roughly weekly releases. Image tag is pinned and digest-locked; bump
deliberately, and back up `/config/scryer.db` **and** the encryption key secret before
upgrading — the DB is unusable without the key that encrypts the credentials stored in
it.

## Shared storage

Mounts the `plex-media` PVC at `/data` — the same volume root qBittorrent mounts at
`/data` and Plex mounts at `/media`. This is deliberate: it puts downloads and library
under one filesystem and one path prefix, so Scryer's import step can hardlink/atomic-move
instead of copying across a network path, and no remote path mapping is needed between
Scryer and qBittorrent.

Plex sees the same files at a different prefix (`/media` vs `/data`), so the Plex
notification plugin needs an explicit path mapping — see below.

## First-run configuration (manual, one-time)

Scryer stores indexers, download clients and notifications in its own encrypted SQLite
DB (`/config/scryer.db`), not in this repo. These steps are done once, in the UI:

1. **Set an admin password.** A fresh install creates an `admin` account with no
   password and form login disabled — nothing prompts for sign-in until this is done.
   Settings → Users → set a password (the literal value `admin` is rejected). Then add
   `SCRYER_AUTH_ENABLED=true` to `deployment.yaml` and commit.
2. **Download client** — install the `qbittorrent` plugin.
   `base_url: http://qbit-neo.default.svc.cluster.local:8080`, credentials from the
   qBittorrent WebUI (only in Scryer's encrypted database, not in git — read them from
   the UI). `routing_mode: category` (default), `post_import_action:
   tag_imported` (default — keeps seeding; do not use `remove_with_data`). The
   `scryer:imported` tag resets on qBittorrent pod restarts since
   `kube/lookie/qbit-neo/qbit-neo-config-file.enc.yaml` is git-authoritative and
   doesn't carry Scryer's tags — cosmetic only, qBittorrent re-registers tags from
   torrent resume data.
3. **Media server** — install the `plex` notification plugin.
   `base_url: http://plex-plex-media-server.default.svc.cluster.local:32400`, a Plex
   token as `auth_token`, `update_library: true`, and critically:
   ```
   path_mappings: /data => /media
   ```
   Without this, Scryer's targeted library-section refresh can't resolve the path and
   won't trigger.
4. **Libraries** — Movies root `/data/Movies`, Series root `/data/TV`. By design, Scryer
   only manages new acquisitions here — pre-existing titles keep their release names and
   are not bulk-imported or renamed.
5. **Indexers** — install the `torznab` plugin (and `nyaa` for anime — Prowlarr doesn't
   cover that as cleanly) from the plugin catalog. Add trackers here as Prowlarr-backed
   Torznab feeds: for each indexer configured in Prowlarr, add a Scryer `torznab` entry
   pointing at `http://prowlarr.default.svc.cluster.local:9696/<indexerid>/api`, API key
   from the `prowlarr-api-key` secret (`<indexerid>` is Prowlarr's numeric ID for that
   indexer, visible in its Torznab feed URL). Prowlarr owns the tracker definitions and
   login flows — see `kube/lookie/prowlarr/README.md`.
6. **Proxy** — Settings → Indexers → **Indexer proxies** (Beta) → **Connect indexer
   proxy**:
   - **Provider**: `Trawl`.
   - **Base URL**: `http://trawl.default.svc.cluster.local:8191` (base URL only —
     Scryer appends `/v1` itself).
   - **Timeout**: `60` seconds (valid range 1–180).
   - **Enabled**: checked, then **Test**.

## Routed through the WireGuard gateway

`spec.template.metadata.labels` carries `setGateway: "true"`, so Scryer's calls out
of the cluster — metadata lookups, artwork, the hosted GraphQL gateway below —
leave through the tunnel rather than the house connection. The mechanism, and
every trap in it, is documented in `kube/lookie/pod-gateway-config/README.md`.
Three things specific to Scryer:

**The `0.0.0.0/0` egress rule was deleted, not merely superseded.** That deletion
is the point of routing this pod. Once the default route is replaced, every
internet flow is encapsulated before it leaves the pod, so kube-router sees a
single UDP packet addressed to the gateway and never the real destination — an
ipBlock allowlist can no longer match anything it was written to match. Leaving
it in place would have been worse than removing it, because it would still read
like a control while allowing and forbidding nothing. Egress is now decided by
the gateway's firewall. If Scryer ever stops being routed, restore a real
allowlist in the same commit that removes the label.

**The pod's security context is meaningfully weaker, and that is a conscious
trade.** The injected `gateway-init` and `gateway-sidecar` run **as root with
`NET_ADMIN` and `NET_RAW` and an empty capability drop list**, hard-coded in the
admission controller and not configurable. Scryer's own container is untouched —
still uid 1000, `runAsNonRoot`, `drop: [ALL]`. You cannot build a VXLAN without
`NET_ADMIN`; this is a trade, not a bug, but a security review should find a
decision here rather than an accident.

**Nothing about the in-cluster pipeline changes.** Prowlarr's Torznab feeds,
Trawl's solver endpoint, qBittorrent's API and Plex are all pod-to-pod, which is
inside `NOT_ROUTED_TO_GATEWAY_CIDRS`, so those flows travel the normal path and
ordinary podSelector rules still apply to them. The `plex-media` mount is
filesystem I/O and never touches the network at all. `networkpolicy.yaml` also
gains the gateway **ingress** rule, which is load-bearing rather than tidy — see
the conntrack section of the gateway README.

## Secrets NOT in git

- `scryer-tls` — cert-manager-issued, regenerates automatically.

Everything else (`scryer-encryption-key`) is in git, SOPS-encrypted, decrypted at sync
time by lookie's Argo CD CMP plugin.

## External dependency

Scryer's title search and artwork go through a first-party hosted GraphQL gateway
(`smg.scryer.media`) that is not open-source and cannot currently be self-hosted. If it's
unavailable, Scryer's core acquisition loop stops working, independent of anything in
this cluster.
