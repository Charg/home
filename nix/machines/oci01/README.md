# `oci01`

Cloud VM running headscale (`headscale.nix`) with embedded DERP as the only relay.

- No LUKS; nothing is there to unlock it at boot
- aarch64, so Colmena builds run on the target (see `nix/colmena`)
- The headscale DNS record must be DNS-only; a proxying CDN breaks the control
  protocol and DERP

## Register nodes

Access is defined in `policy.hujson` (default deny). Decide whether a node is
personal or tagged when registering it; converting later is painful.

Personal devices belong to a user whose name matches `group:admin`:

```bash
ssh nixos@oci01 sudo headscale users list   # --user takes the numeric ID
ssh nixos@oci01 sudo headscale preauthkeys create --user <ID>
```

Headless hosts are tagged nodes:

```bash
ssh nixos@oci01 sudo headscale preauthkeys create --tags tag:server
```

On the node:

```bash
tailscale up --login-server <SERVER_URL> --authkey <KEY>
```

## NAS backup

`nas-backup.nix` holds an off-site restic repository that
`kube/nuc01/nas-backup` pushes to. The pusher can only add snapshots; pruning
and a partial `restic check` run monthly from `nas-backup-prune.timer`.
