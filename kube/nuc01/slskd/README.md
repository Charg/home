# slskd

[slskd](https://github.com/slskd/slskd), a headless Soulseek client with a
WebUI. All Soulseek traffic leaves through a ProtonVPN WireGuard tunnel in a
gluetun sidecar, with a Proton forwarded port so peers can connect in.

Served at `https://slskd.home.packet.fail` on `traefik-internal`.

## Images

All three digest-pinned; bump tag and digest together.

| purpose | image |
|---|---|
| Soulseek client | `ghcr.io/slskd/slskd:0.26.2` |
| tunnel | `ghcr.io/qdm12/gluetun:v3.41.3` |
| resolver | `registry.k8s.io/coredns/coredns:v1.14.6` |

## Why not the shared pod-gateway

`kube/nuc01/pod-gateway` routes prowlarr and trawl out through one shared
tunnel, but it runs with `VPN_PORT_FORWARDING=off`, and even with it on the
forwarded port would land on the gateway pod, not here. Without an inbound
port, transfers with any peer that is itself firewalled fail with
"Connection timeout", which on Soulseek is a large share of users. Same
reasoning as lookie's qbit-neo, which also keeps its own sidecar.

## Port forwarding

No scripts. slskd has a built-in gluetun integration (`SLSKD_VPN*`): it polls
gluetun's control server (`/v1/publicip/ip`, `/v1/portforward`) every 2.5s and,
when the forwarded port changes, re-binds its listener and tells the Soulseek
server the new port, without reconnecting. That covers both the cold start and
Proton's rotation seconds later.

It also gates the connection: slskd stays disconnected from Soulseek until
gluetun reports a non-zero port, and disconnects if the control server stops
answering. A brief "Waiting for VPN" after start is normal.

gluetun's control server is bound to `127.0.0.1:8000` and requires an API key
(`HTTP_CONTROL_SERVER_AUTH_DEFAULT_ROLE`). Unauthenticated, it would let any
caller change the tunnel.

## Leak containment

- gluetun's firewall drops outbound traffic outside the tunnel, except to the
  pod and service CIDRs.
- slskd's VPN integration disconnects Soulseek when the tunnel is not ready.
- The NetworkPolicy denies egress to the LAN (`192.168.0.0/16`).

Unlike qbit-neo there is **no interface binding**: slskd's
`listen_ip_address` takes an IP, and the tunnel address can change on
reconnect, so it stays `0.0.0.0`. Peer transfers already in flight when the
tunnel drops are covered only by gluetun's firewall.

## Settings

Every slskd setting is managed as an `SLSKD_*` env var in `deployment.yaml`,
so it lives in git and changes roll out through Argo CD.

Do not set anything in `/app/slskd.yml` on the volume, or through the WebUI's
options editor. YAML **overrides** env in slskd, so a value set there silently
wins over `deployment.yaml` and drifts from git. Leave the file as generated
(all commented out). Options that only exist in YAML, such as per-peer daily
and weekly upload limits, are not in use.

## Storage

`slskd-data` is a 100Gi `synology-iscsi-storage` volume (RWO, `Retain`,
expandable) mounted at `/app`: `data/` (SQLite), `logs/`, `downloads/`,
`incomplete/`, and the generated `slskd.yml`. RWO and SQLite are why the
Deployment is `replicas: 1` with `strategy: Recreate`.

`/app/downloads` is also the share. Many Soulseek users refuse uploads to
peers that share nothing; change `SLSKD_SHARED_DIR` to share something else.
Shares are re-scanned every 12h (`SLSKD_SHARE_CACHE_RETENTION`, in minutes),
so a finished download can take up to that long to appear; rescan from the
WebUI to share it sooner.

slskd runs as uid 1000 through the image's non-root path. `/.net` (the
single-file bundle extracts its native libraries there) and `/tmp` are
`emptyDir`s.

## Secrets

- `slskd-wireguard`: Proton WireGuard **private key only**, as `privatekey`.
  Must be a separate Proton config from qbit-neo's and the pod-gateway's (one
  key is one Proton session), generated with **NAT-PMP (port forwarding)** on.
- `slskd-secrets`:
  - `soulseek-username` / `soulseek-password`: the Soulseek account.
  - `web-username` / `web-password`: the WebUI login.
  - `jwt-key`: fixed so WebUI sessions survive a restart.
  - `gluetun-api-key`, and `gluetun-auth-role`, which embeds the same key as
    `{"auth":"apikey","apikey":"…"}`. Change both together.

Edit with `sops kube/nuc01/slskd/<file>.enc.yaml`. Decrypted at sync time by
the Argo CD SOPS plugin.

## Flat directory, on purpose

The SOPS plugin only reads top-level `*.yaml`/`*.yml` files. Keep every
manifest flat in this directory, and keep this README a `.md`.
