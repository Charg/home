# qbittorrent

This is a plain-manifest app, no upstream Helm chart exists for this deployment.

## Storage

Shares the `plex-media` PVC (RWX, `synology-iscsi-storage`) with Plex — mounted at
`/config` (`subPath: qbittorrent-config`) and at `/data` (volume root). Plex mounts the
same PVC at `/media`. This is what lets Scryer (`kube/lookie/scryer/`) do atomic-move /
hardlink imports: qBittorrent downloads to `/data/downloads`, Scryer imports into
`/data/Movies` and `/data/TV`, both under the same filesystem.

## Config is git-authoritative

`qbittorrent-config-file.enc.yaml` holds `qBittorrent.conf`, seeded into
`/config/qBittorrent/config/` by the `init-qbittorrent` initContainer on every pod start.

**Git is the source of truth for this file** A pod restart reverts any WebUI change that wasn't committed.

## Secrets

Everything else the StatefulSet needs (`qbittorrent-secret`, `qbittorrent-wireguard`,
`qbittorrent-config-file`) **is** in git now, SOPS-encrypted, decrypted at sync time by
lookie's Argo CD CMP plugin (`kube/lookie/argocd/values.yaml`).
