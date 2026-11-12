# `framework`

Disk layout is declared in `disk-config.nix`:

- `ESP` (1G, `/boot`)
- LUKS `cryptroot` → LVM VG `pool`
  - `pool/swap` (64G, resume device)
  - `pool/system`: btrfs with subvolumes `root` (`/`), `nix` (`/nix`), `home` (`/home`)

`root` and `nix` can be recreated on reinstall without touching `home`.

Host secrets are decrypted with the SSH host key, which must be present at
`/etc/ssh/ssh_host_ed25519_key` before first boot.
