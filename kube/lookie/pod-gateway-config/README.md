# pod-gateway

A WireGuard egress gateway for selected pods in `default`. A pod that opts in
loses its own default route and gets all non-cluster traffic tunnelled out
through this gateway, with external DNS resolved over DoT inside that tunnel.

Two Argo Applications make it up:

| app | what it owns |
|---|---|
| `pod-gateway` | the upstream Helm chart, values in `kube/lookie/pod-gateway/values.yaml` |
| `pod-gateway-config` | this directory: the WireGuard key, the two ConfigMaps, the admission webhook config, and the backstop NetworkPolicy |

`qbit-neo` is deliberately **not** on this gateway. See
`kube/lookie/qbit-neo/README.md` for why.

## How a pod opts in

Add `setGateway: "true"` to `spec.template.metadata.labels`. Never to
`spec.selector` - a Deployment's selector is immutable, and a routing flag has no
business being part of a workload's identity.

Two gotchas in the mutator, both verified against a throwaway pod:

- **The value goes through `strconv.ParseBool`.** Only `"true"`, `"false"` and
  ParseBool's other spellings are safe. `setGateway: "yes"` makes the mutator
  return an error, and because `failurePolicy: Fail` the pod is **rejected** with
  `could not mutate object: strconv.ParseBool: parsing "yes": invalid syntax`.
  That is the intended outcome - see the `objectSelector` note below.
- **An annotation of the same name is evaluated after the label and overrides
  it.** A pod labelled `setGateway: "true"` and annotated `setGateway: "false"`
  comes up unrouted. Do not use both.

## Why this repo carries its own MutatingWebhookConfiguration

The chart's `templates/webhook-admissionregistration.yaml` renders only a
`namespaceSelector` and omits `failurePolicy` entirely, so the API server
defaults it to `Fail`. That left two options and both were unacceptable:

- **Namespace-scoped with `Fail`.** Every pod CREATE in `default` becomes gated on
  this webhook being up with a valid serving certificate. That namespace holds
  the DNS server the house resolves through, metallb-speaker, cloudflared, the
  kube-prometheus stack, akri, plex and home-assistant. One certificate renewal
  failure or unlucky boot ordering and nothing schedules in `default` at all -
  including the thing that answers DNS for the house.
- **`failurePolicy: Ignore`.** The pod is admitted unmutated. It keeps its normal
  default route and normal `ClusterFirst` DNS and **leaks silently while looking
  perfectly healthy**. That is the exact failure this whole design exists to
  prevent.

`admissionregistration.k8s.io/v1` supports `objectSelector`, which narrows
interception to pods carrying the opt-in label. The chart simply does not
template it. So `mutatingwebhookconfiguration.yaml` here is a hand-written
replacement, and the chart's own config is left in place but inert - its
`namespaceSelector` in `values.yaml` matches a label that exists nowhere.

With scope narrowed to pods that asked to be routed, `Fail` becomes the **safe**
choice: webhook down means opted-in pods are rejected, so nothing starts
unrouted, and every other pod in `default` never reaches the webhook at all.

The `objectSelector` matches the label's **presence**, not the exact value
`"true"`. Matching only `"true"` would let a `setGateway: "yes"` typo through
unmutated *and* unfenced, because `networkpolicy-routed.yaml` selects that same
exact value. Matching Exists routes those typos to the webhook to be rejected
loudly instead.

> **A major chart bump is not a Renovate merge.** The webhook template is
> hand-maintained here and has to be diffed against upstream by hand.
> Renovate's generic helm regex manager will still open the PR; it just cannot
> be merged unreviewed. The template is short and has been stable across the
> 7.x line.

## A second fail-closed property

The webhook calls `net.LookupIP` on the gateway's name on **every** admission,
not just at startup. If the gateway pod is gone the headless Service returns
NXDOMAIN, the mutator errors, and with `failurePolicy: Fail` the pod is rejected.
**You cannot start a client while the gateway is down.** That is correct, and it
is worth knowing before it surprises someone at 2am.

## The backstop NetworkPolicy

`networkpolicy-routed.yaml` selects on the same label that opts a pod in - the
label that routes you also fences you. It covers what admission cannot: someone
deleting the webhook config, `gatewayDefault` getting flipped, or a hand-run pod
carrying the label. In any of those the pod keeps its normal default route but
has no permission to use it, so it fails closed instead of leaking.

Two egress rules and no more:

- To the gateway, with **no `ports:` restriction**. It has to carry ICMP as well
  as the VXLAN, because `client_init.sh` pings the gateway pod address and
  `client_sidecar.sh` pings the VXLAN address every ten seconds, and
  NetworkPolicy cannot express ICMP any other way.
- To kube-dns on 53. `client_init.sh` resolves the gateway by name *before* the
  tunnel exists.

Note what is **not** there: any internet destination at all. All of that traffic
is inside the VXLAN, so kube-router only ever sees the outer UDP packet to the
gateway. That is why default-deny works here without an allowlist - and it is
also why **destination allowlists on a routed pod are decorative**. The gateway's
own firewall and its egress NetworkPolicy are the real control.

`policyTypes: [Egress]` only, deliberately. Adding `Ingress` here would flip
`prowlarr` and `trawl` - which have no ingress policy of their own - to
default-deny inbound the moment they are labelled, breaking Traefik in a way that
has nothing to do with egress. Ingress stays in each app's own policy file.

## The conntrack trap

The item most likely to burn an afternoon. **Each routed app needs an explicit
ingress rule allowing the gateway**, in its own policy file.

VXLAN return traffic is a separate conntrack flow, not a reply. The client sends
`(clientIP:hash -> gatewayIP:4789)`; the gateway sends
`(gatewayIP:hash -> clientIP:4789)`. Different five-tuples, so a
`RELATED,ESTABLISHED` accept does not cover it.

Without that rule the injected init container **passes** its `ping <gatewayPodIP>`
- plain ICMP with a real reply - and then hangs on `udhcpc` or on pinging the
VXLAN address. The symptom points at DHCP; the cause is ingress policy.

## Settings that are traps, not tuning

All in `kube/lookie/pod-gateway/values.yaml`, which explains each one inline. In
short:

- **`NOT_ROUTED_TO_GATEWAY_CIDRS`** - the chart default is `""` with a comment
  claiming "(Flannel does)". Flannel adds a route for the pod CIDR but **not**
  the service CIDR. Left at the default, every ClusterIP connection goes down the
  tunnel, gets forwarded back out and is **masqueraded**, so in-cluster peers see
  the gateway's address instead of the client's - quietly breaking every
  podSelector-based NetworkPolicy in the namespace.
- **`VXLAN_PORT`** - the image default is the *string* `"0"`, which
  `gateway_init.sh` treats as set and turns into
  `iptables -A INPUT -p udp --dport=0`. The real port then never gets an INPUT
  accept and the tunnel dies the moment gluetun applies `INPUT DROP`.
- **`VPN_BLOCK_OTHER_TRAFFIC: true`** - gluetun sets `--policy FORWARD DROP`, and
  the only thing that adds a matching accept is this flag's
  `iptables -I FORWARD -o $VPN_INTERFACE -j ACCEPT`. Set false, the tunnel comes
  up healthy and no client packet is ever forwarded.
- **`DNS_LOCAL_SERVER`** - set explicitly, because `gateway_sidecar.sh` would
  otherwise derive it from a `/etc/resolv.conf` this pod deliberately points at
  loopback.

### The MTU chain

Pod `eth0` is 1450. VXLAN costs 50 and WireGuard 60, so `VPN_INTERFACE_MTU` and
`WIREGUARD_MTU` are both 1320: that becomes 1370 on `eth0` and 1380 on the wire,
both under 1450, so nothing fragments. Leave it unset and large TLS handshakes
hang while ping and DNS work perfectly - a miserable thing to diagnose.

Do **not** rely on the chart's clamp-to-`eth0`−50 branch. It is dead code in both
`gateway_init.sh` and `client_init.sh`: the test is written
`[ ${VPN_INTERFACE_MTU} >= ${VXLAN0_INTERFACE_MAX_MTU} ]`, and bash parses `>` as
an output redirection to a file literally named `=`, leaving `[` with two
arguments and an error return. The `else` branch always wins, so `vxlan0` gets
exactly what is configured.

### Two resolvers, two loopback addresses

The gateway pod runs dnsmasq (the chart's `main` container) **and** CoreDNS.
dnsmasq serves clients on `172.16.0.1`; CoreDNS is the split-horizon resolver
that sends cluster names to kube-dns and everything else to DoT inside the
tunnel.

CoreDNS binds **`127.0.0.2`**, not `127.0.0.1`. `gateway_sidecar.sh` runs dnsmasq
with `interface=vxlan0 bind-interfaces`, which reads as "bind `172.16.0.1` only"
but is not - dnsmasq always includes the loopback interface, so it also claims
`127.0.0.1:53`. Sharing that address crashlooped the `main` container with
`failed to create listening socket for 127.0.0.1: Address in use`. Separate
addresses also sidestep dnsmasq discarding any upstream nameserver that matches
an address it is itself listening on.

CoreDNS is deliberately used rather than gluetun's own resolver: gluetun binds
wildcard `:53` regardless of `DNS_ADDRESS`, which would collide with dnsmasq.
gluetun therefore runs `DNS_SERVER=off` with `DNS_KEEP_NAMESERVER=on`;
`DNS_ADDRESS=127.0.0.1` is not a substitute, as `qbit-neo`'s notes record.

## The gluetun post-rules ConfigMap

`gluetun-post-rules-configmap.yaml` is the least obvious piece of the design, and
skipping it produces a gateway that looks perfectly healthy and forwards nothing.

`gateway_init.sh` is a true init container, so it does **not** re-run when a
single container restarts. gluetun's `disable()` calls `clearAllRules`, which is
`iptables --flush --delete-chain` **without `-t nat`** - so the `MASQUERADE`
survives but every filter-table rule `gateway_init.sh` added is gone, and on the
way back up gluetun re-asserts `FORWARD DROP` with nothing to match. The symptom
is a `Running` pod with `wg0` up and every client silently offline.

gluetun replays `/iptables/post-rules.txt` at the end of **every** firewall
enable (`runUserPostRules`), and `runIptablesInstruction` just splits fields and
execs, so `-t nat` is accepted there. Verified on first deploy at
`LOG_LEVEL=debug`: all six instructions appear, including
`iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE`.

If a future gluetun rejects `-t nat` here, the fallback is operational rather
than a code change - see the runbook below.

## The gateway's own egress NetworkPolicy is load-bearing

It lives in `kube/lookie/pod-gateway/values.yaml` under `networkpolicies` (note
the lowercase key - the camelCase spelling silently renders nothing in this chart
and in `bjw-s common` v5). It is not decorative and should not be trimmed.

It closes the window between gluetun's `disable()` - which returns its policies to
ACCEPT and tears down `wg0` while leaving the `MASQUERADE` in the nat table - and
the pod actually dying, during which forwarded client traffic could otherwise
exit via `eth0` in the clear. kube-router evaluates the host `FORWARD` chain
before flannel's `POSTROUTING` SNAT, so the source is still the gateway pod's
address and the policy applies.

Do not "harden" it by adding `Ingress` without also allowing UDP/4789 from the
pod CIDR, or you cut off every client.

## Known trades

### The kube-dns residual hole

A query from a routed pod aimed **directly** at kube-dns will resolve, and would
leave via the node. This is intentional: kube-dns is on the backstop policy's
allowlist because `client_init.sh` needs it to bootstrap the tunnel, and closing
it would break the tunnel's own startup.

The pod's *configured* resolver is the gateway, so an application has to go out of
its way to hit it. Corroborated rather than closed: with a routed pod working,
external names appear in the gateway's dnsmasq log forwarded to `127.0.0.2` and
CoreDNS holds ESTABLISHED TLS sessions to the DoT upstreams **sourced from the
`wg0` address**, i.e. inside the tunnel. A direct query at the LAN resolver's
address from a routed pod is refused by kube-router while the same query from an
unlabelled pod succeeds.

### Every routed pod gains two root containers

The injected `gateway-init` and `gateway-sidecar` run **as root with `NET_ADMIN`
and `NET_RAW` and an empty capability drop list**. That is hard-coded in
`gatewayPodMutator.go` and is not configurable.

The app container itself is untouched, but the pod's overall security context is
meaningfully weaker - most visibly for `prowlarr`, which otherwise runs
`runAsNonRoot`, uid 1000, `drop: [ALL]`. This is inherent to the mechanism: you
cannot build a VXLAN without `NET_ADMIN`. It is a trade, not a bug, but it should
read as a decision rather than an accident.

### A routed pod can never have a public client address

Inbound is untouched - `client_init.sh` only rewrites the client's routing table,
so a SYN arrives at `eth0` exactly as before. The **reply** is where it breaks:
once the default route is deleted, a reply is only deliverable if its destination
matches one of the routes installed from `NOT_ROUTED_TO_GATEWAY_CIDRS`.

Traefik-internal SNATs, and kubelet's probes come from the node or the CNI
bridge, so all of those stay in the not-routed ranges and keep working. But
anything whose real client address is **public** breaks: the reply matches no
not-routed route, goes down the tunnel, and is dropped as asymmetric. So a routed
pod can never be exposed through the public Traefik instance or through a Service
with `externalTrafficPolicy: Local`.

Get that CIDR list wrong and every routed pod goes `NotReady` about thirty
seconds after it starts, which is a confusing way to discover a routing typo.

## Out-of-repo preconditions

Two things this gateway needs that are not expressed in this repo:

- The node must carry the `net.ipv4.conf.all.src_valid_mark` unsafe-sysctl
  kubelet argument, for the same reason `qbit-neo` does. The symptom of its
  absence is a `Pending` pod with a `SysctlForbidden` event.
- Nothing on the node may route anything in `172.16/12`, the VXLAN subnet.

cert-manager used to be a third: the chart's webhook serving Certificate asks for
`additionalOutputFormats: CombinedPEM`, which lookie's hand-installed v1.14.4
rejected at admission because the `AdditionalCertificateOutputFormats` feature
gate was still alpha and off by default. cert-manager is now an ApplicationSet
element at v1.21.1, where that gate is on by default, so this is version-
controlled rather than a precondition.

## Expected noise, not bugs

`gateway_init.sh` sets `OUTPUT DROP` with no `-o lo` accept, so there is a
sub-second window at start where dnsmasq cannot reach the in-pod CoreDNS.
gluetun's own firewall adds the loopback accept moments later. It appears in the
logs; ignore it.
