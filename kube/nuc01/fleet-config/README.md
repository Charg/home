# fleet

[Fleet](https://fleetdm.com), the osquery management server. Served at
`https://fleet.home.packet.fail` on `traefik-internal`, for both the UI and
the agents.

## Layout and rollout

Four Argo CD apps in namespace `fleet`, defined in `kube/nuc01/fleet-apps`
and ordered by sync waves. That directory has its own parent app
(`app-of-apps/application_fleet_apps.yaml`), so the waves only wait on these
four apps:

| wave | app | contents |
|---|---|---|
| 1 | `fleet-mysql` | MySQL 8.4 StatefulSet, nightly dump to backup-rustfs |
| 1 | `fleet-redis` | redis-operator `Redis` |
| 1 | `fleet-config` | this directory: server Secret, Ingress, NetworkPolicies, PodMonitor |
| 2 | `fleet` | the `fleetdm/fleet` chart, values in `kube/nuc01/fleet/values.yaml` |

The chart's migration Job runs as a PreSync hook, so it needs the database
up first; that is what the waves are for. It also retries on its own if the
database is not ready yet.

## Image and chart

Bump the chart version (`fleet-apps/fleet.yaml`) and the
digest-pinned `imageTag` (`kube/nuc01/fleet/values.yaml`) together, along
with the `fleetctl` pin in `nix/common/fleetctl.nix`.

## First run

The setup page creates the first admin and is open until that happens, so
do it right after the first sync. Then, under Settings:

- set the Fleet web address to `https://fleet.home.packet.fail`
- turn off usage statistics (the server has no internet egress)

## Agents

NixOS hosts enroll through `nix/common/fleetd.nix`. Their enroll secret
lives in `nix/machines/<host>/secrets/fleet.enc.yaml` (the same value on
every host) and has to be one of Fleet's global enroll secrets. After
`fleetctl login`, register it with:

```sh
secret=$(sops decrypt --extract '["fleet-enroll-secret"]' nix/machines/nuc01/secrets/fleet.enc.yaml)
f=$(mktemp --suffix=.yaml)  # fleetctl apply wants a .yaml/.yml name
printf 'apiVersion: v1\nkind: enroll_secret\nspec:\n  secrets:\n    - secret: %s\n' "$secret" > "$f"
fleetctl apply -f "$f"
rm -f "$f"; unset secret
```

This replaces the global secret list, so rotating it means updating every
host's file and re-running the above.

## Secrets

- `fleet-server`: `private-key` (encrypts sensitive data in the database;
  changing it makes that data unreadable) and the `/metrics` basic-auth
  credentials used by the PodMonitor.
- `fleet-mysql/fleet-mysql-credentials`, `fleet-redis/fleet-redis-credentials`:
  read by the chart directly.

Edit with `sops kube/nuc01/<dir>/<file>.enc.yaml`. Decrypted at sync time by
the Argo CD SOPS plugin.

## Flat directory, on purpose

The SOPS plugin only reads top-level `*.yaml`/`*.yml` files. Keep every
manifest flat in this directory, and keep this README a `.md`.
