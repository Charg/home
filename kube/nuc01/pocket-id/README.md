# pocket-id

[Pocket ID](https://pocket-id.org), a passkey-only OIDC provider. It is the
login for `kube/nuc01/tinyauth` and for apps that speak OIDC themselves.

Served at `https://id.home.packet.fail` on `traefik-internal`.

## Image

Digest-pinned; bump tag and digest together.

| purpose | image |
|---|---|
| IdP | `ghcr.io/pocket-id/pocket-id:v2.19.2` |

## Hostname is permanent

Passkeys are bound to the origin in `APP_URL`. Changing it invalidates every
enrolled passkey, so treat the hostname as fixed.

## First run

The setup page at `/setup` creates the first admin and is open until that
happens, so do it right after the first sync. Enroll a passkey on every
device you log in from, plus a hardware key as the fallback; there is no
password login.

## Storage

`pocket-id-data` is a 1Gi `longhorn` volume mounted at `/app/data`: the
SQLite database, signing keys and uploads. RWO and SQLite are why the
Deployment is `replicas: 1` with `strategy: Recreate`.

## Secrets

- `pocket-id-secrets`: `encryption-key`, which wraps the token signing keys
  in the database. Losing it means re-creating the instance.

Edit with `sops kube/nuc01/pocket-id/<file>.enc.yaml`. Decrypted at sync time
by the Argo CD SOPS plugin.

## Flat directory, on purpose

The SOPS plugin only reads top-level `*.yaml`/`*.yml` files. Keep every
manifest flat in this directory, and keep this README a `.md`.
