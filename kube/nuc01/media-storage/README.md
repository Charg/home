# media-storage

Existing volumes for the media stack, bound statically rather than provisioned.

| file | used by |
|---|---|
| `plex-media.yaml` | Plex, qbit-neo, Scryer, copyparty (Movies, read-only) |
| `plex-config.yaml` | Plex |

- The reclaim policy is `Retain`, so deleting a claim or volume here keeps the data.
- The volumes are single-writer. Every pod that mounts `plex-media` is pinned to
  the same node, and a new consumer must be pinned the same way.
