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

`HEALTH_TARGET_ADDRESSES` is an IP (`1.1.1.1:443`) on purpose. A hostname would make the
tunnel's own health check depend on a resolver whose upstream depends on the tunnel — a
circular wait that presents as a tunnel that never goes healthy.

### Restarting the sidecar in place is safe — no wrapper needed

A gluetun sidecar can restart without the pod being recreated (liveness blip, `kill 1`), and
the pod's network namespace outlives it — so the restarted container finds its own tunnel
interface and policy rules already present. On some gluetun versions that means it fails to
re-add them, crashloops, and wedges the pod: dead, but not leaking, since qBittorrent keeps
running behind a DROP-by-default firewall.

**v3.41.3 does not do this.** Verified on this pod by killing PID 1 twice in a row — the
second kill is the one that would trip over state left by the first. Both times gluetun
returned to a healthy tunnel, with no `file exists` errors, no duplicated policy rules, and
qBittorrent never restarting. It reconfigures the existing link and rules idempotently.

So there is deliberately **no cleanup wrapper** here. If a future gluetun bump reintroduces
the wedge, this is the first thing to re-test; the fix is a small ConfigMap-backed script
set as the sidecar's `command` that deletes rule priorities 98–101 and the tunnel link, then
`exec`s `/gluetun-entrypoint`.

## Split-horizon DNS

A CoreDNS sidecar on `127.0.0.1:53` sends cluster zones to kube-dns and everything else out
over the tunnel by DoT. That gets both halves: `*.svc.cluster.local` resolves (which the
legacy instance gave up entirely), while tracker and peer lookups stay encrypted and
in-tunnel instead of leaking to the LAN and the ISP.

It fails **closed** — with the tunnel down, external resolution fails rather than falling
back to an off-tunnel path. Cluster names may still resolve; that is expected.

Three constraints shape the implementation, each verified rather than assumed:

- **`/etc/resolv.conf` is one file shared by every container in the pod**, not per-container.
  gluetun rewrites it, so it has to be told not to — `DNS_KEEP_NAMESERVER=on`. The obvious
  alternative, pointing `DNS_ADDRESS` at `127.0.0.1` so its rewrite is a no-op, **does not
  work**: gluetun will not point resolv.conf at loopback when its own forwarder is off and
  silently writes its bootstrap upstream (`nameserver 1.1.1.1`) instead.
- **gluetun's own resolver binds wildcard `:53`**, not the address it is configured with, so
  it cannot coexist with CoreDNS in one namespace and is switched off outright.
- **Reverse zones are split deliberately.** Only `10.in-addr.arpa` and `168.192.in-addr.arpa`
  go to kube-dns. Forwarding `in-addr.arpa` wholesale would send peer rDNS — public
  addresses — to the cluster resolver and out to the LAN, which is the leak this is avoiding.

It needs `NET_BIND_SERVICE` added back after `drop: [ALL]` to bind port 53, and the `health`
plugin is omitted because it defaults to wildcard `:8080` and would collide with qBittorrent's
WebUI in the shared namespace.

### The CoreDNS sidecar deliberately has no probe

Do not add one. Every kind is unusable here, and getting this wrong does not degrade the pod
— it **wedges it**:

- `tcpSocket` and `httpGet` are dialled by kubelet from the **node**, at the **pod IP**. This
  resolver binds `127.0.0.1` only, so neither can ever connect — the same constraint that
  makes gluetun's probe an `exec`.
- `exec` has nothing to run: the image ships only the `/coredns` binary, with no shell, no
  `dig` and no `nslookup`.

A `startupProbe` that can never pass is worse than no probe at all, because on a **native
sidecar** the containers listed after it never start — the pod sits in `Init:` forever rather
than coming up degraded.

Nothing races on this. gluetun reaches its servers by IP and health-checks an IP, so it needs
no resolver at all; qBittorrent, which does, starts only after gluetun's own probe passes, by
which point CoreDNS has been listening for minutes.

## Leak containment

Two independent mechanisms, both required:

1. **gluetun's firewall** defaults to DROP outbound outside the tunnel.
2. **`Session\Interface=wg0` / `Connection\Interface=wg0`** in the seeded config binds
   qBittorrent's sockets to the tunnel interface. Without this, peer flows that are already
   established survive a tunnel teardown and fall back to the pod's normal route. Do not
   drop these keys to "simplify" — the firewall alone does not cover established flows.

   These names have to agree with `VPN_INTERFACE` on the gluetun sidecar, which is why that
   is set to `wg0` rather than left at gluetun's `tun0` default. **A mismatch fails open,
   not closed**: qBittorrent logs `The configured network interface is invalid` and then
   keeps listening unbound, so the containment silently disappears while everything still
   looks healthy. If you change one, change the other.

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
