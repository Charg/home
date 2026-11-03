# bitmagnet

[bitmagnet](https://github.com/bitmagnet-io/bitmagnet), with a Torznab feed
consumed by Prowlarr. Plain manifests. Served on `traefik-internal` only; the
UI has no auth.

## Image

Upstream's `ghcr.io/bitmagnet-io/bitmagnet`, unsigned. Bump tag and digest
together, and check the digest was pushed by upstream CI before a bump.

Runs as uid/gid `1000`, read-only root filesystem, no capabilities, no
writable volumes. Config is env in `deployment.yaml` plus the classifier
secret; all state is in Postgres.

## Database

`kube/nuc01/bitmagnet-postgres`: a single-instance CNPG cluster, 50Gi on
`synology-iscsi-storage`. It only grows; expand `storage.size` before it fills.
No backups. The password is set once by `initdb`; editing the secret does not
change it.

## Networking

Routed through the shared gateway (`setGateway: "true"`); see
`kube/nuc01/media-config/README.md`. `DHT_CRAWLER_SCALING_FACTOR` sets crawl
concurrency and so load on the gateway. Before raising it, check conntrack
inside the gateway pod (its own netns, not visible in node metrics) and this
pod's CPU throttling.

## Metrics

`/metrics` on the HTTP port, scraped by `podmonitor.yaml`. Crawl rate:
`rate(bitmagnet_dht_crawler_persisted_total{entity="Torrent"}[1h])`.

## Classifier

Rules live in `bitmagnet-classifier.enc.yaml` (`sops` to edit), mounted at
`/etc/xdg/bitmagnet` and selected with `CLASSIFIER_WORKFLOW`. Read only at
start: restart the deployment after changing it. Rules apply to newly crawled
torrents; to apply them to the existing index, run `bitmagnet reprocess` in
the pod.

## Secrets

`bitmagnet-secrets` (optional), key `tmdb-api-key`. Create it as
`bitmagnet-secrets.enc.yaml` here and encrypt with `sops -e -i`, then restart
the deployment.

## Flat directory, on purpose

The SOPS plugin only reads top-level `*.yaml`/`*.yml` files. Keep every
manifest flat in this directory, and keep this README a `.md`.
