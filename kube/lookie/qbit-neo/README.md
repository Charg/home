# qbit-neo

A second [qBittorrent](https://www.qbittorrent.org/) instance, running its
traffic through a WireGuard tunnel in a [gluetun](https://github.com/qdm12/gluetun)
sidecar.

## Node prerequisite, outside this repo

The pod sets the unsafe sysctl `net.ipv4.conf.all.src_valid_mark=1`, which gluetun's
WireGuard needs. It is only schedulable because lookie's kubelet is started with
`--kubelet-arg=allowed-unsafe-sysctls=net.ipv4.conf.all.src_valid_mark`. That setting
lives on the node, not in this repo. **If the node is rebuilt without it, this pod will
not schedule** — the symptom is a pod stuck `Pending` with a `SysctlForbidden` event.

## Images

All four digest-pinned; bump tag and digest together.

| purpose | image |
|---|---|
| tunnel | `ghcr.io/qdm12/gluetun:v3.41.3` |
| torrent client | `ghcr.io/home-operations/qbittorrent:5.2.3` |
| config seed | `docker.io/library/busybox:1.38` |

`ghcr.io/home-operations/qbittorrent` for the same reason Prowlarr uses that family: no
s6-overlay, so it does no boot-time `chown` and needs none of the half-dozen capabilities
an s6-based image would want back. Its PID 1 is `catatonit`.

## Tunnel and startup ordering

gluetun is a **native sidecar** — an init container with `restartPolicy: Always`. Kubernetes
gates the next container on a sidecar having *started*, which is why the gate on gluetun is
a **`startupProbe`** and not a `readinessProbe`:

- A `readinessProbe` on a sidecar holds nothing back — qBittorrent would start regardless,
  and could announce itself before the tunnel existed.
- It would also feed pod readiness, so a momentary tunnel blip would yank the Service
  endpoint out from under Traefik and take the WebUI down with it.

The probe execs `/gluetun-entrypoint healthcheck` rather than using `httpGet`, because
gluetun's health server binds `127.0.0.1:9999` and kubelet sends `httpGet` probes to the
**pod IP** — which would never reach a loopback listener.

gluetun's control server is pinned to `127.0.0.1:8000` via `HTTP_CONTROL_SERVER_ADDRESS`.
It defaults to wildcard and exposes tunnel control **with no authentication**, so that
setting is load-bearing, not tidiness.

`HEALTH_TARGET_ADDRESS` is an IP (`1.1.1.1:443`) on purpose. A hostname would make the
tunnel's own health check depend on a resolver whose upstream depends on the tunnel — a
circular wait that presents as a tunnel that never goes healthy.

## Leak containment

Two independent mechanisms, both required:

1. **gluetun's firewall** defaults to DROP outbound outside the tunnel.
2. **`Session\Interface=wg0` / `Connection\Interface=wg0`** in the seeded config binds
   qBittorrent's sockets to the tunnel interface. Without this, peer flows that are already
   established survive a tunnel teardown and fall back to the pod's normal route. Do not
   drop these keys to "simplify" — the firewall alone does not cover established flows.

## Storage, and not colliding with the legacy instance

Both pods mount the same RWX `plex-media` PVC, so the separation is by path:

`/data`, `/data/downloads` and `/config` on that volume are all owned by uid 0. That is why
this pod pins `runAsUser: 0` even though the image would happily run as uid 65534: it
cannot write to the shared tree otherwise. Root here is bounded — all capabilities dropped,
`allowPrivilegeEscalation: false`, nothing privileged.

## Config is git-authoritative

`qbit-neo-config-file.enc.yaml` holds the whole `qBittorrent.conf`, and the `config-seed`
init container copies it over `/config/qBittorrent/qBittorrent.conf` with `cp -f` on **every**
start. Consequences worth knowing before you touch the WebUI:

- **Changes made in the WebUI do not survive a restart.** To change a setting for real,
  change it here and let Argo roll the pod.
- The WebUI password is therefore also set here, as a `WebUI\Password_PBKDF2` hash
  (PBKDF2-HMAC-SHA512, 100000 iterations, 16-byte salt, stored as
  `@ByteArray(<b64 salt>:<b64 hash>)`). It is distinct from the legacy instance's.

Note the config path: `/config/qBittorrent/qBittorrent.conf`. This image has **no**
`config/` subdirectory, unlike the layout the legacy app's image uses.

`[LegalNotice] Accepted=true` is required — qBittorrent 5.x otherwise blocks on an
interactive stdin prompt and the container never becomes ready.

`WebUI\AuthSubnetWhitelistEnabled=false` deliberately overrides the image default, which
ships `10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16` whitelisted **and enabled**. Left on,
every request arriving through Traefik comes from a cluster address and would therefore
skip authentication entirely.

## Secrets

- `qbit-neo-wireguard` — the WireGuard **private key only**, as key `privatekey`.

  Deliberately not a `wg0.conf`. gluetun runs its own server selection against Proton's
  server list to find a port-forward-capable server; a mounted config file would override
  only the *endpoint* underneath that selection, so the server gluetun thinks it picked and
  the one it actually connects to would disagree, and port forwarding would then succeed or
  fail at random on each restart.

  It is a separate Proton identity from the legacy instance's, not a copy. One WireGuard key
  is one Proton session — sharing a key would mean the two pods fighting over one tunnel.

- `qbit-neo-config-file` — the `qBittorrent.conf` above.
- `qbit-neo-tls` — cert-manager-issued, regenerates automatically.

Both `.enc.yaml` files are decrypted at sync time by lookie's Argo CD CMP plugin
(`kube/lookie/argocd/values.yaml`); they match the existing `kube/lookie/.*\.enc\.yaml$`
rule in `.sops.yaml`, so no `.sops.yaml` change was needed.

## Flat directory, on purpose

The SOPS CMP globs `find . -maxdepth 1 -type f -name '*.yaml'` and concatenates the results.
Anything in a subdirectory is **silently ignored**, and any non-manifest `.yaml` left in
here gets emitted as a manifest. Keep every manifest a flat `.yaml` in this directory, and
keep this README a `.md`.
