# tinyauth

[Tinyauth](https://tinyauth.app), a forward-auth service for Traefik. It
puts a login in front of apps that have none of their own, delegating the
login itself to `kube/nuc01/pocket-id`.

Served at `https://auth.home.packet.fail` on `traefik-internal`. Only the
login page and the OAuth callback go through the ingress; the auth check is
Traefik calling the service directly.

## Image

Digest-pinned; bump tag and digest together.

| purpose | image |
|---|---|
| forward-auth | `ghcr.io/tinyauthapp/tinyauth:v5.2.0` |

## Protecting an app

Add the middleware to the app's Ingress:

```yaml
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: auth-tinyauth@kubernetescrd
```

`traefik-internal` runs with `allowCrossNamespace` for this. The session
cookie is scoped to the parent domain, so one login covers every protected
host under it, and the app must be under that domain.

Clients that call an app's API with a key, rather than a browser, cannot pass
the login. Leave those apps unannotated or move the API to another host.

## Setup

1. In Pocket ID, create an OIDC client named `tinyauth` with callback URL
   `https://auth.home.packet.fail/api/oauth/callback/pocketid`.
2. Put the client ID and secret in `tinyauth-secrets`.

Until step 2 the pod runs but every login fails at the IdP.

## Storage

`tinyauth-data` is a 1Gi `longhorn` volume mounted at `/data`: sessions and
keys. RWO and SQLite are why the Deployment is `replicas: 1` with
`strategy: Recreate`.

## Secrets

- `tinyauth-secrets`: `oauth-client-id` and `oauth-client-secret` from the
  Pocket ID client.

Edit with `sops kube/nuc01/tinyauth/<file>.enc.yaml`. Decrypted at sync time
by the Argo CD SOPS plugin.

## Flat directory, on purpose

The SOPS plugin only reads top-level `*.yaml`/`*.yml` files. Keep every
manifest flat in this directory, and keep this README a `.md`.
