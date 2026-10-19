# media-config

Shared plumbing for the `media` namespace. Today that is the supporting
resources for a WireGuard egress gateway; the gateway itself is the
`pod-gateway` Helm app, values in `kube/nuc01/pod-gateway/values.yaml`.

A pod that opts in loses its own default route and has all non-cluster traffic
tunnelled out through the gateway, with external DNS resolved over DoT inside
that tunnel. Everything else in `media` is untouched and never reaches the
admission webhook.

| file | what it is |
|---|---|
| `namespace.yaml` | the `media` namespace, owned here so it does not depend on app sync order |
| `pod-gateway-wireguard.enc.yaml` | the gateway's WireGuard private key |
| `coredns-configmap.yaml` | the gateway's in-pod split-horizon resolver |
| `gluetun-post-rules-configmap.yaml` | firewall rules gluetun replays after every restart |
| `mutatingwebhookconfiguration.yaml` | the real admission webhook config, with an `objectSelector` |
| `networkpolicy-routed.yaml` | backstop egress policy for every routed pod |

## Opting a pod in

Add `setGateway: "true"` to `spec.template.metadata.labels`. Never to
`spec.selector`, which is immutable.

- The value goes through `strconv.ParseBool`. A typo such as `"yes"` is
  rejected at admission, loudly, rather than starting unrouted.
- An annotation of the same name overrides the label. Do not use both.
- **Each routed app needs an ingress rule allowing the gateway pod** in its own
  NetworkPolicy. VXLAN return traffic is a separate conntrack flow, not a reply,
  so `ESTABLISHED` does not cover it. Without the rule the injected init
  container passes its ping to the gateway and then hangs on DHCP.
- A routed pod cannot be served to public clients (public Traefik, or
  `externalTrafficPolicy: Local`): replies to public addresses go down the
  tunnel and are dropped. Internal Traefik and kubelet probes are unaffected.
- `ipBlock` egress allowlists stop meaning anything once a pod is routed, since
  the CNI only sees the encapsulated packet to the gateway. Delete them rather
  than leave a rule that reads like a control. In-cluster `podSelector` rules
  and all ingress rules still apply.

## Why the webhook config lives here

The chart renders a webhook with only a `namespaceSelector` and no
`failurePolicy`, which defaults to `Fail`. Scoped to the whole namespace, that
would gate every pod CREATE in `media` on the webhook, including the webhook's
own pod and the gateway pod, so neither could restart without the other already
up. `failurePolicy: Ignore` would admit opted-in pods unmutated, leaking
silently.

So the chart's own config is left inert (its selector matches nothing) and
`mutatingwebhookconfiguration.yaml` adds an `objectSelector` on the `setGateway`
label. Scoped to pods that asked to be routed, `Fail` is the safe choice: webhook
down means opted-in pods are rejected and nothing starts unrouted.

The selector matches the label's presence, not the value `"true"`, so typos are
sent to the webhook to be rejected instead of slipping past both it and the
backstop policy.

A major chart bump needs this file diffed against the chart's
`templates/webhook-admissionregistration.yaml` by hand.

## The backstop NetworkPolicy

Selects on the same label that opts a pod in. It covers what admission cannot:
the webhook config being deleted, or a hand-run pod carrying the label. Such a
pod keeps its default route but has no permission to use it.

It allows only the gateway pod (no port restriction, because the client scripts
also ping it) and kube-dns on 53 (the client resolves the gateway by name before
the tunnel exists). Egress only, so it never changes a routed app's ingress.

## Settings that are traps, not tuning

- **`routed_namespaces: []`.** The chart renders its settings ConfigMap into
  `routed_namespaces` plus the release namespace. The gateway and its clients
  share `media`, so listing it would render the same ConfigMap twice.
- **`NOT_ROUTED_TO_GATEWAY_CIDRS`** must include the service CIDR. Flannel only
  routes the pod CIDR; without the service CIDR, ClusterIP traffic is tunnelled,
  masqueraded and arrives from the gateway's address, breaking `podSelector`
  policies.
- **`VXLAN_PORT`** must be set. The image default is the string `"0"`, which
  produces a firewall rule for port 0 and a tunnel that dies when gluetun's
  firewall comes up.
- **`VPN_BLOCK_OTHER_TRAFFIC: true`** adds the only `FORWARD` accept matching
  gluetun's `FORWARD DROP`. Without it nothing is forwarded.
- **`DNS_LOCAL_SERVER`** is set explicitly because the gateway pod's own
  resolver points at loopback.
- **MTU 1320** for both `VPN_INTERFACE_MTU` and `WIREGUARD_MTU`. Pod `eth0` is
  1450; VXLAN costs 50 and WireGuard 60. Unset, large TLS handshakes hang while
  ping and DNS work. The chart's auto-clamp is dead code and cannot be relied on.
- **The gateway uses `Recreate`.** The client scripts take a single answer from
  the headless Service; two ready gateway pods break every reconnecting client.
- **`dnsConfig` stays per-controller.** The webhook copies its own
  `resolv.conf` into every client, so it must never inherit the gateway's
  loopback resolver.

### Two resolvers

dnsmasq (the chart's `main` container) serves clients on `172.16.0.1`. CoreDNS,
bound to `127.0.0.2`, sends cluster names to kube-dns and everything else to DoT
inside the tunnel. Not `127.0.0.1`: dnsmasq always claims loopback too. gluetun's
own resolver is off (`DNS_SERVER=off`, `DNS_KEEP_NAMESERVER=on`) because it binds
wildcard `:53`.

### The post-rules ConfigMap

The chart's `gateway_init.sh` runs once as an init container. If only the
gluetun container restarts, gluetun flushes the filter table and re-asserts
`FORWARD DROP`, leaving a `Running` gateway that forwards nothing. gluetun
replays `/iptables/post-rules.txt` at the end of every firewall enable, which
restores the rules.

### The gateway's own egress policy

Defined under `networkpolicies` (lowercase; the camelCase key renders nothing).
It allows only WireGuard out plus in-cluster traffic, closing the window during
a gluetun shutdown where forwarded traffic could otherwise leave in the clear. Do
not add `Ingress` to it without allowing UDP/4789 from the pod CIDR.

## Failure behaviour

- **Gateway down:** routed pods lose egress; there is no fallback route. They
  recover without restarting once the gateway is back, after up to about half a
  minute (`CONNECTION_RETRY_COUNT` trades reconnect speed for cold-boot
  tolerance), on a new exit address.
- **Clients created while the gateway is down** sit in `Init` under kubelet
  backoff and can take minutes to recover after the gateway is healthy.
- **Webhook down:** opted-in pods are rejected at admission; every other pod in
  `media` schedules normally.
- **Cold boot** is noisy: clients crashloop until the gateway has a tunnel. It
  converges on its own.

## Break-glass

Argo's `selfHeal` reverts each of these within seconds to minutes. Disable
`automated` on the owning Application first if the workaround has to hold.

| symptom | action |
|---|---|
| Opted-in pods rejected at admission | Delete `mutatingwebhookconfiguration/pod-gateway-routed`. Pods then start unrouted, held only by the backstop policy. |
| A labelled pod needs egress now | Delete `networkpolicy/pod-gateway-routed` and the app's own egress policy. |
| Clients lost egress but the gateway is `Running` | Delete the gateway pod; check gluetun's log at `LOG_LEVEL=debug` for rejected post-rules. |

## Node requirements

- The kubelet allows the `net.ipv4.conf.all.src_valid_mark` unsafe sysctl, set
  for every node in `nix/users/nixos/nixos.nix`. Without it the gateway pod stays
  `Pending` with `SysctlForbidden`.
- Nothing on a node routes the VXLAN subnet, `172.16.0.0/24`.

Clients and the gateway may land on different nodes. The gateway's VXLAN then
rides inside flannel's, which the host firewall already allows between peers.

## The WireGuard key

The key permits NAT-PMP but gluetun runs with `VPN_PORT_FORWARDING=off`, so no port is ever requested.
