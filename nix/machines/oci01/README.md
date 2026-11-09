# `oci01` install

Oracle Cloud Always Free Ampere A1 VM running headscale.

This machine uses:
- `disko` GPT layout from `disk-config.nix` (no LUKS, nobody to unlock it at boot)
- headscale with built-in Let's Encrypt and embedded DERP as the only relay (`headscale.nix`)
- aarch64, so builds run on the target

The VM, network and firewall are provisioned separately with Terraform. It
boots Ubuntu, which `nixos-anywhere` replaces with NixOS.

## 1) DNS

Point the headscale hostname (`domain` in `headscale.nix`) at the VM's public
IP with a DNS-only record. A proxying CDN breaks the Tailscale control
protocol and DERP. Headscale requests its certificate on the first TLS
connection, so the record must resolve publicly before any client connects.

## 2) Stage host SSH key and install (control machine)

The Ubuntu image's login is `ubuntu` with passwordless sudo, which
`nixos-anywhere` uses to kexec into the installer.

```bash
#!/usr/bin/env bash
set -euo pipefail

temp=$(mktemp -d)
cleanup() {
  rm -rf "$temp"
}
trap cleanup EXIT

install -d -m755 "$temp/etc/ssh"
ssh-keygen -t ed25519 -N "" -f "$temp/etc/ssh/ssh_host_ed25519_key"
# keep a copy of the host key somewhere safe
chmod 600 "$temp/etc/ssh/ssh_host_ed25519_key"

nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$temp" \
  --flake .#oci01 \
  --build-on remote \
  --kexec-extra-flags '--kexec-syscall' \
  --target-host ubuntu@<OCI01_IP>
```

`kexec_file_load` fails on the Ubuntu OCI kernel with "Address not
available", so `--kexec-extra-flags` forces the legacy `kexec_load` syscall.

## 3) Manage with Colmena

`oci01` is defined in `nix/colmena/managed.nix`. If `oci01` doesn't resolve,
add it to your SSH config with the public IP.

```bash
nix run github:zhaofengli/colmena -- --config ./nix/colmena/managed.nix apply --on oci01
```

## 4) Register nodes

Access is defined in `policy.hujson` (default deny). Decide whether a node is
personal or tagged when registering it; converting later is painful.

Personal devices (laptops, phones) belong to a user. The user name must match
`group:admin` in the policy:

```bash
ssh nixos@oci01 sudo headscale users create <USER>
ssh nixos@oci01 sudo headscale users list   # --user takes the numeric ID
ssh nixos@oci01 sudo headscale preauthkeys create --user <ID>
```

Headless hosts are tagged nodes, owned by the tag rather than a user:

```bash
ssh nixos@oci01 sudo headscale preauthkeys create --tags tag:server
```

On the node:

```bash
tailscale up --login-server <SERVER_URL> --authkey <KEY>
```

## 5) NAS backup volume

`nas-backup.nix` keeps an off-site restic repository on a separate block
volume, attached with Terraform. `kube/nuc01/nas-backup` pushes to it. Once
the volume is attached, format it and create the repository, one time only:

```bash
ssh nixos@oci01 lsblk                        # the new, empty disk; usually sdb
ssh nixos@oci01 sudo mkfs.ext4 -L backup /dev/sdb
ssh nixos@oci01 sudo systemctl restart srv-backup.mount
ssh nixos@oci01 sudo install -d -o nas-backup -g nas-backup -m 700 /srv/backup/restic
ssh nixos@oci01 sudo -u nas-backup \
  RESTIC_PASSWORD_FILE=/run/secrets/nas-backup-restic-password \
  restic -r /srv/backup/restic init
```

The pusher can only add snapshots. Pruning and a partial `restic check` run
monthly from `nas-backup-prune.timer`.
