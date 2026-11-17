# website

The personal site at `syn.sh`: static files served by nginx, built from
[Charg/website](https://github.com/Charg/website).

Served through the Cloudflare tunnel (`kube/nuc01/cloudflared`), not Traefik.
The public hostname is set in the Cloudflare dashboard, pointing at
`http://website.website.svc.cluster.local:8080`. No Ingress, Certificate or
external-dns record.

## Image

`ghcr.io/charg/website:main`, rebuilt by GitHub Actions on every push to main.
Each build is also tagged `sha-<short>` for rollbacks.

The deployment pins `main@sha256:<digest>`. Renovate opens a digest-bump PR
for each new build and auto-merges it, outside the repo's Monday schedule and
release-age delay (see the own-artifacts rules in `.renovaterc.json5`). Argo CD
then rolls the deployment.

To publish immediately, merge the open Renovate PR (or trigger a Renovate run
from the Dependency Dashboard issue).

To roll back, set `image` to a `sha-<short>` tag here and commit; Renovate
will pin its digest. Auto-updates stop until `image` is back on `main`.

## Flat directory, on purpose

The SOPS plugin only reads top-level `*.yaml`/`*.yml` files. Keep every
manifest flat in this directory, and keep this README a `.md`.
