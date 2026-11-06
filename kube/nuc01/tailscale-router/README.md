# tailscale-router

Tailnet subnet routers for the home LAN, registered with the headscale server
in `nix/machines/oci01`. Two routers advertise the same routes; headscale
picks one as primary and fails over to the other.

Each router is its own single-replica StatefulSet pinned to one node, on the
host network, with its own WireGuard UDP port. The edge router forwards each
port to its node, and the node firewall opens it.

| StatefulSet | node | UDP port |
|---|---|---|
| `tailscale-router-mpc00` | mpc00 | 41641 |
| `tailscale-router-mpc01` | mpc01 | 41642 |

## Image

Digest-pinned; bump tag and digest together.

| purpose | image |
|---|---|
| router | `ghcr.io/tailscale/tailscale:v1.104.4` |

## Setup

1. On oci01, mint a key for the `tag:router` tag:
   `sudo headscale preauthkeys create --tags tag:router --reusable --expiration 1h`
2. Put it in `tailscale-router-authkey`.
3. Check `sudo headscale nodes list-routes` shows both routers, routes
   approved.

The key is only used on first login. After that each router's identity lives
in its `tailscale-router-<node>-state` Secret. Delete that Secret to
re-register a router with a fresh key.

## Secrets

- `tailscale-router-authkey`: `authkey`, the headscale pre-auth key.

Edit with `sops kube/nuc01/tailscale-router/<file>.enc.yaml`. Decrypted at
sync time by the Argo CD SOPS plugin.

## Flat directory, on purpose

The SOPS plugin only reads top-level `*.yaml`/`*.yml` files. Keep every
manifest flat in this directory, and keep this README a `.md`.
