# `nuc01` install and remote LUKS unlock

This machine uses:
- `disko` GPT layout from `disk-config.nix`
- LUKS root device named `cryptroot`
- initrd SSH unlock on port `2222` (DHCP)

## Manage with Colmena

`nuc01` is defined in `nix/colmena/managed.nix`.

Preview and evaluate:

```bash
nix run github:zhaofengli/colmena -- --config ./nix/colmena/managed.nix eval -E '{ nodes, ... }: builtins.attrNames nodes'
nix run github:zhaofengli/colmena -- --config ./nix/colmena/managed.nix eval -E '{ nodes, ... }: nodes.nuc01.config.deployment.targetHost'
```

Deploy to `nuc01`:

```bash
nix run github:zhaofengli/colmena -- --config ./nix/colmena/managed.nix apply --on nuc01
```

Deploy with elevated parallelism and verbose logs:

```bash
nix run github:zhaofengli/colmena -- --config ./nix/colmena/managed.nix apply --on nuc01 --parallel 4 -v
```

Notes:
- Node deploy metadata currently uses `targetHost = "nuc01"` and `targetUser = "nixos"`.
- If your network does not resolve `nuc01`, update `deployment.targetHost` in `nix/colmena/managed.nix`.

## 1) Create a luks password (control machine)

```bash
umask 077
tr -cd '[:alnum:]' < /dev/urandom | head -c 24 > /tmp/nuc01-luks.txt
```

Save the above to your password manager.

## 2) Stage host SSH key (control machine)

Manage the initrd SSH host key by injecting it during install with `--extra-files`.

```bash
#!/usr/bin/env bash
set -euo pipefail

temp=$(mktemp -d)
cleanup() {
  rm -rf "$temp"
}
trap cleanup EXIT

install -d -m755 "$temp/etc/ssh"
ssh-keygen -t ed25519 -N "" -f "$temp/etc/ssh/ssh/ssh_host_ed25519_key"
cp "$temp/etc/ssh/ssh_host_ed25519_key" ~/keys/
chmod 600 "$temp/etc/ssh/ssh_host_ed25519_key"

nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$temp" \
  --flake /home/framework/code/home#nuc01 \
  --target-host root@<NUC_IP> \
  --disk-encryption-keys /tmp/luks.txt /tmp/luks.txt
```
