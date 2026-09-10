# `mpc01` install and remote LUKS unlock

This machine uses:
- `disko` GPT layout from `disk-config.nix`
- LUKS root device named `cryptroot`
- initrd SSH unlock on port `2222` (DHCP)
- Static address `192.168.74.12` via UDM DHCP reservation

## Manage with Colmena

`mpc01` is defined in `nix/colmena/managed.nix`.

Preview and evaluate:

```bash
nix run github:zhaofengli/colmena -- --config ./nix/colmena/managed.nix eval -E '{ nodes, ... }: builtins.attrNames nodes'
nix run github:zhaofengli/colmena -- --config ./nix/colmena/managed.nix eval -E '{ nodes, ... }: nodes.mpc01.config.deployment.targetHost'
```

Deploy to `mpc01`:

```bash
nix run github:zhaofengli/colmena -- --config ./nix/colmena/managed.nix apply --on mpc01
```

Notes:
- Node deploy metadata uses `targetHost = "mpc01"` and `targetUser = "nixos"`.
- If your network does not resolve `mpc01`, use `192.168.74.12` directly
  until a DNS A record is added.

## 1) Create a luks password (control machine)

```bash
umask 077
tr -cd '[:alnum:]' < /dev/urandom | head -c 24 > /tmp/luks.txt
```

Save the above to your password manager.

## 2) Stage host SSH key and install (control machine)

Same `--extra-files` mechanism as `nuc01`'s install: generate a fresh host
SSH key, keep a copy locally, and pass it to `nixos-anywhere`.

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
cp "$temp/etc/ssh/ssh_host_ed25519_key" ~/keys/
chmod 600 "$temp/etc/ssh/ssh_host_ed25519_key"

nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$temp" \
  --flake /home/framework/code/home#mpc01 \
  --target-host root@<MPC01_IP> \
  --disk-encryption-keys /tmp/luks.txt /tmp/luks.txt
```

## 3) Before running the install for real

1. Boot the NixOS installer ISO on the physical hardware first, run
   `nixos-generate-config`, and replace `hardware-configuration.nix` with
   the real output. Commit that before proceeding.
2. Confirm the static IP reservation for this node's real MAC has been
   added in your network's DHCP configuration.
