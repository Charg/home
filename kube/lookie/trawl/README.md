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

## First-run configuration (manual, one-time)

Nothing to configure on Trawl itself - it's stateless beyond the Redis cache. All
setup happens on the Scryer side; see `kube/lookie/scryer/README.md`.

## Secrets

None. No `.enc.yaml` files in this directory.
