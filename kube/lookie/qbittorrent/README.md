# qbittorrent

Adopted into GitOps from a 2024 out-of-band Helm release (`chart qbittorrent-0.0.1`,
namespace `default`). This is a plain-manifest app — no upstream Helm chart exists for
this deployment, so it's the first plain-manifest app on `lookie` (pattern copied from
`kube/nuc01/cloudflared/` and `kube/nuc01/ac-rustfs/`).

## Storage

Shares the `plex-media` PVC (RWX, `synology-iscsi-storage`) with Plex — mounted at
`/config` (`subPath: qbittorrent-config`) and at `/data` (volume root). Plex mounts the
same PVC at `/media`. This is what lets Scryer (`kube/lookie/scryer/`) do atomic-move /
hardlink imports: qBittorrent downloads to `/data/downloads`, Scryer imports into
`/data/Movies` and `/data/TV`, both under the same filesystem.

## Config is git-authoritative

`qbittorrent-config-file.enc.yaml` holds `qBittorrent.conf`, seeded into
`/config/qBittorrent/config/` by the `init-qbittorrent` initContainer on every pod start.
**Git is the source of truth for this file** — the intended workflow is: change a setting
in the WebUI, pull the resulting config back out, commit it here. A pod restart reverts
any WebUI change that wasn't committed. See `../scryer/README.md` and the repo's plan
history for why this tradeoff was chosen over letting the WebUI own it unconditionally.

Note: `init-wireguard`'s command list carries a 4th, dead element (a leftover `&& if...fi`
string that becomes a positional parameter to `sh -c`, not additional script, and never
executes). Preserved verbatim rather than fixed, to keep the initial adoption commit a
true no-op against the running release. Clean up in a separate change if you want to.

## Secrets NOT in git

These exist as live Kubernetes secrets only and must be recreated by hand if ever lost —
nothing in this repo can regenerate them:

- `sops-age-key` (namespace `argocd`) — the age identity that decrypts everything below.
- `qbittorrent-internal-tls` — cert-manager-issued TLS cert, regenerates automatically.

Everything else the StatefulSet needs (`qbittorrent-secret`, `qbittorrent-wireguard`,
`qbittorrent-config-file`) **is** in git now, SOPS-encrypted, decrypted at sync time by
lookie's Argo CD CMP plugin (`kube/lookie/argocd/values.yaml`).
