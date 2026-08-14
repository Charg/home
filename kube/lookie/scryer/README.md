# scryer

[scryer-media/scryer](https://github.com/scryer-media/scryer) — a Sonarr/Radarr-style
media manager. No upstream Helm chart exists, so this is a plain-manifest app (same
pattern as `kube/lookie/qbittorrent/` and `kube/nuc01/cloudflared/`).

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
   `SCRYER_AUTH_ENABLED=true` to `deployment.yaml` and commit — see the comment in that
   file.
2. **Download client** — install the `qbittorrent` plugin.
   `base_url: http://qbittorrent.default.svc.cluster.local:8080`, credentials from the
   qBittorrent WebUI. `routing_mode: category` (default), `post_import_action:
   tag_imported` (default — keeps seeding; do not use `remove_with_data`). The
   `scryer:imported` tag resets on qBittorrent pod restarts since
   `kube/lookie/qbittorrent/qbittorrent-config-file.enc.yaml` is git-authoritative and
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
   only manages new acquisitions here — the existing ~470 titles keep their release names
   and are not bulk-imported or renamed.
5. **Indexers** — install `torznab` (and `nyaa` for anime) from the plugin catalog and
   add trackers.
6. **Indexer proxies (challenge solving)** — for indexers behind a Cloudflare/CAPTCHA
   wall (nyaa, 1337x), Settings → Indexers → **Indexer proxies** (Beta) → **Connect
   indexer proxy**:
   - **Provider**: `Trawl` — not `Byparr`. Scryer sends `maxTimeout` in milliseconds
     for the `Trawl` provider and seconds for `Byparr`; picking the wrong one silently
     breaks the timeout. Immutable after creation — delete and recreate to change it.
   - **Base URL**: `http://trawl.default.svc.cluster.local:8191` (base URL only —
     Scryer appends `/v1` itself).
   - **Timeout**: `60` seconds (valid range 1–180).
   - **Enabled**: checked, then **Test** (probes `GET <base_url>/health`; a Trawl pod
     that restarted in the last ~30s reports Unhealthy while its browser pool warms up
     — retest rather than debugging).

   Then attach the proxy **per indexer** (a nullable field on each indexer, not
   Prowlarr-style tag matching) — edit `nyaa` and `1337x` and select the `trawl`
   proxy; leave unchallenged indexers unset. See `kube/lookie/trawl/README.md` for
   why Trawl and not FlareSolverr/Byparr.

## Secrets NOT in git

- `scryer-tls` — cert-manager-issued, regenerates automatically.

Everything else (`scryer-encryption-key`) is in git, SOPS-encrypted, decrypted at sync
time by lookie's Argo CD CMP plugin.

## External dependency

Scryer's title search and artwork go through a first-party hosted GraphQL gateway
(`smg.scryer.media`) that is not open-source and cannot currently be self-hosted. If it's
unavailable, Scryer's core acquisition loop stops working, independent of anything in
this cluster.
