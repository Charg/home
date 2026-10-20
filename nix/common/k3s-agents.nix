# Worker-only k3s nodes. Unlike k3s-nodes.nix (the etcd servers), these may be
# offline at any time, so they never join etcd.
{
  tortuga = "192.168.73.9";
}
