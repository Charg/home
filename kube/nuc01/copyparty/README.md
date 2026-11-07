# copyparty

[copyparty](https://github.com/9001/copyparty), a file server for sharing the
Movies, TV and Anime folders of `plex-media` outside the LAN, read-only.

Served on `traefik-public` with a DNS-only Cloudflare record; the host is in
`ingress.yaml`.

## Image

Digest-pinned; bump tag and digest together.

| purpose | image |
|---|---|
| file server | `copyparty/min:1.20.26` |

## Access

Two locks, both in `copyparty-config`:

- `ipar`: allowed client IPs. It reads the client address from Traefik's
  `X-Forwarded-For`, trusted only from pod IPs (`xff-src`). Do not swap it
  for `ipa`, which sees only Traefik.
- `[accounts]`: read-only logins on the `/movies`, `/tv` and `/anime` volumes.

The container mounts only those three folders, read-only, so nothing else on
the volume can be exposed by a config mistake.

## Storage

`plex-media` is single-writer, so the pod is pinned to the same node as the
other consumers (see `kube/nuc01/media-storage`). Sessions and copyparty's
own state are in an `emptyDir`.

## Secrets

- `copyparty-config`: the whole `copyparty.conf`.

Edit with `sops kube/nuc01/copyparty/copyparty-config.enc.yaml`, then bump
`checksum/config` in `deployment.yaml`; the config is only read at startup.
Decrypted at sync time by the Argo CD SOPS plugin.

## Flat directory, on purpose

The SOPS plugin only reads top-level `*.yaml`/`*.yml` files. Keep every
manifest flat in this directory, and keep this README a `.md`.
