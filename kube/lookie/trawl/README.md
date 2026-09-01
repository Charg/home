# trawl

[germondai/trawl](https://github.com/germondai/trawl) — a self-hosted web scraping
engine with JS-challenge and CAPTCHA solving (Cloudflare, Akamai, Imperva/Incapsula,
Turnstile, reCAPTCHA, hCaptcha, GeeTest). No upstream Helm chart or Kubernetes
manifests exist upstream, so this is a plain-manifest app (same pattern as
`kube/lookie/scryer/` and `kube/lookie/qbittorrent/`).

Deployed for Scryer to use as a proxy.

## ⚠️ No `plugin: {}` on this app's Argo CD Application

Unlike `application_scryer.yaml` and `application_qbittorrent.yaml`,
`application_trawl.yaml` deliberately omits `plugin: {}`. The SOPS CMP plugin is
selected by `discover.find.glob: "**/*.enc.yaml"` (see
`kube/lookie/argocd/values.yaml`) - Trawl has no secrets, so that glob matches
nothing and forcing the plugin route fails to resolve. If a secret is ever added to
this app, add `plugin: {}` back to the Application at the same time.

## No storage

No PVC. Two things could have needed one and neither does:

- **The MITM forward-proxy CA** (`MITM_PROXY_CA_DIR`) - not applicable, see below.
- **Redis** - a pure session cache with a 30-minute TTL server-side and a 1-hour
  `SESSION_TTL_SECONDS` default. Backed by an `emptyDir`; losing it on pod restart
  costs some fresh solves, nothing more.

## MITM proxy stays off

Trawl also offers a challenge-bypassing HTTP/HTTPS forward proxy (port 8192,
`MITM_PROXY_ENABLED`). It's not used by Scryer, so it's left off (the default).

## Image pinning

Pre-1.0-adjacent, frequent releases. Two tags exist per version on the same GHCR
package: the plain tag (modern Bun runtime, needs AVX2 + kernel 5.1+) and a
`-baseline` suffix (older CPUs / Synology / older kernels). `lookie` has AVX2 and
kernel 5.15, so the plain tag is correct. `:latest` tracks tip of `main`, not
releases - pin an explicit semver tag and digest, and bump deliberately.

## Routed through the WireGuard gateway

`spec.template.metadata.labels` carries `setGateway: "true"`, so every page Trawl
fetches loads from the tunnel's exit rather than the house connection. The
mechanism, and every trap in it, is documented in
`kube/lookie/pod-gateway-config/README.md`. Four things specific to Trawl:

**Init ordering is load-bearing here, because this pod already had a native
sidecar.** The admission controller *appends* `gateway-init` to
`initContainers`, so the list becomes `[redis, gateway-init]`: Redis comes up and
its `startupProbe` passes before the gateway's VXLAN exists, then `gateway-init`
builds the tunnel, then the `trawl` container starts. That order is correct only
because Redis needs no network beyond loopback. **Any future native sidecar in
this pod that needs the internet would start before `gateway-init` and see either
no default route or the wrong one.** Such a sidecar has to move into
`containers:` — or the pod has to stop being routed.

**Every fetch is now a tunnel fetch, and the solve rate is the thing to watch.**
Challenge providers score datacenter and VPN address ranges more harshly than
residential ones, so a challenge that solves from the house connection can start
failing from the exit. Measured before and after the switch, from inside
the `trawl` container, as five cache-busted `request.get` solves against a live
Cloudflare challenge page:

| | solves | steady-state per solve |
|---|---|---|
| house connection | 5/5 | ~6-7s |
| tunnel exit | 5/5 | ~6s |

(First solve after a pod start is slower either way — 14s and 17s respectively —
which is the browser pool warming, not the exit.) So the switch cost nothing
measurable. Re-run the same comparison before believing any later report that it
did; a target that has simply got harder looks identical from the outside. If
challenges do start failing in a way that tracks the exit rather than the target,
removing the label from `deployment.yaml` is the revert, and it is a one-line one.

Pick discriminating targets when re-measuring. `nowsecure.nl` serves no challenge
to either exit and solves sub-second from both, so it proves reachability and
nothing about challenge difficulty.

**The pod's security context is meaningfully weaker, and that is a conscious
trade.** The injected `gateway-init` and `gateway-sidecar` run **as root with
`NET_ADMIN` and `NET_RAW` and an empty capability drop list**. That is hard-coded
in the admission controller and is not configurable. This is inherent to the
mechanism: you cannot build a VXLAN without `NET_ADMIN`. It is a trade, not a bug,
but a security review should find a decision here rather than an accident.

**Trawl can never be exposed with a public client address.** Inbound is
untouched, but once the default route is deleted a reply is only deliverable if
its destination matches one of the routes installed from
`NOT_ROUTED_TO_GATEWAY_CIDRS`. `traefik-internal` SNATs and kubelet's probes come
from the node or the CNI bridge, all in that list. A *public* client address
matches no not-routed route, so the reply would go down the tunnel and be dropped
as asymmetric. `trawl-internal` must therefore stay on `traefik-internal`, and
the Service must never get `externalTrafficPolicy: Local`.

`networkpolicy.yaml` includes the gateway **ingress** rule, which is load-bearing
rather than tidy — see the conntrack section of the gateway README. Scryer's and
Prowlarr's calls to `POST /v1` are unaffected: those flows are in the pod range,
which is in `NOT_ROUTED_TO_GATEWAY_CIDRS`, so they travel the normal path.

## First-run configuration (manual, one-time)

Nothing to configure on Trawl itself - it's stateless beyond the Redis cache. All
setup happens on the Scryer side; see `kube/lookie/scryer/README.md`.

## Secrets

None. No `.enc.yaml` files in this directory.
