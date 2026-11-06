# fleet

[Fleet](https://fleetdm.com), the osquery management server. Served at
`https://fleet.home.packet.fail` on `traefik-internal`, for both the UI and
the agents.

## Layout and rollout

Four Argo CD apps in namespace `fleet`, ordered by app-of-apps sync waves:

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

Bump the chart version (`app-of-apps/application_fleet.yaml`) and the
digest-pinned `imageTag` (`kube/nuc01/fleet/values.yaml`) together.

## First run

The setup page creates the first admin and is open until that happens, so
do it right after the first sync. Then, under Settings:

- set the Fleet web address to `https://fleet.home.packet.fail`
- turn off usage statistics (the server has no internet egress)

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
