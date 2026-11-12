# `mpc00`

k3s server (etcd member) in the `nuc01` cluster.

- LUKS root (`cryptroot`), unlocked over initrd SSH on port `2222`
- Deployed with Colmena (see `nix/colmena`)
