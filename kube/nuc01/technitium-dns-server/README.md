# technitium-dns-server

Primary LAN resolver: recursive DNS with ad/malware blocking (StevenBlack + oisd
blocklists), deployed as a redundant pair. Replaces the obeone `technitium-dnsserver`
release with the in-house chart at
[`oci://ghcr.io/charg/technitium-dns-server`](https://github.com/Charg/charts/tree/main/charts/technitium-dns-server).

## Why this chart

The obeone chart models a single instance (one Deployment, one PVC, one Service), so
HA meant two separate Helm releases. This chart is a StatefulSet with
`perReplicaService`, so **one release** gives N independent resolvers, each with its
own PVC and its own pinned LoadBalancer address — and it supports Technitium's native
clustering (v14+), which the obeone chart does not.

## Topology

- `replicaCount: 2` — two independent resolvers. Each `volumeClaimTemplate` PVC is
  `local-path` (hostPath-backed), so a bound PVC pins its replica to the node that
  claimed it; combined with `podAntiAffinity: required` the two never share a node.
- Per-replica LoadBalancer addresses, index-aligned to the StatefulSet ordinals:

  | Replica | Address | Notes |
  |---|---|---|
  | replica-0 | `192.168.74.52` | the address the current resolver already holds |
  | replica-1 | `192.168.74.53` | next free in the MetalLB pool |

  Pool is `192.168.74.50-.69`; `.50`/`.51` are `traefik-internal`/`traefik-public`.
  Pinned via `perReplicaService.loadBalancerIPs` so a Service recreation can't move
  the LAN's resolver.

## Prerequisite: a multi-node cluster

`podAntiAffinity: required` means **replica-1 stays `Pending` until a second node
exists.** This change is staged for the nuc01 + mpc00 + mpc01 consolidation; on the
current single-node cluster only replica-0 (`.52`) schedules. Merge alongside the node
join, or temporarily set `replicaCount: 1` to run degraded before then.

## Cutover order (replacing the obeone release)

The apps ApplicationSet sets `preserveResourcesOnDeletion: true`, so **removing the old
`technitium-dnsserver` element does _not_ prune its running resources** — the obeone
StatefulSet/Service keeps holding `.52` and would block replica-0 from claiming it.
Sequence:

1. Merge this branch. Argo removes the obeone Application from the generator but leaves
   its workload running (preserve-on-deletion).
2. Manually delete the obeone workload to free `.52`:
   `kubectl --context=nuc delete deploy,svc,pvc -l app.kubernetes.io/instance=technitium-dnsserver -n default`
   (verify the label first with `kubectl get all -n default | grep technitium`).
3. The `technitium-dns-server` StatefulSet then claims `.52`/`.53`.

## Admin password

Seeded on first boot from the `technitium-admin` Secret (key `password`), applied by
the `technitium-config` Application from
[`../technitium-dns-server-config`](../technitium-dns-server-config). It is mounted via
`DNS_SERVER_ADMIN_PASSWORD_FILE`, so the password never enters the pod's process
environment. To rotate, edit the SOPS secret **and** change it in the console (the env
seed is first-boot-only — see below).

## First-boot-only configuration

Everything in `values.yaml` that maps to a `DNS_SERVER_*` variable (blocklists,
recursion mode, domain, admin password, local-time logging) is read **only** when a
replica boots against an empty PVC. `helm upgrade` after a value change does **not**
reconfigure an already-initialised replica. Reconfigure through the web console / HTTP
API, or wipe the PVC to re-seed. There is no automatic sync between the two replicas'
config today — keep them identical by hand until native clustering or the operator owns
this state.

## Next steps (not in this change)

- **Native clustering (v14+):** init replica-0 (`.52`) as cluster primary, join
  replica-1 (`.53`); put `packet.fail` in the cluster catalog zone so records replicate
  primary → secondary. Requires the HTTPS API (`webService.enableHttps`, on by default).
- **external-dns → Technitium:** switch the provider from Cloudflare to RFC2136 (or the
  Technitium webhook) writing to the primary, for split-horizon `packet.fail`.
- **UDM DHCP:** hand out `.52`/`.53` as the LAN resolvers (per-VLAN, in the Ubiquiti
  Terraform) once the pair is verified. Nothing queries these until then.
