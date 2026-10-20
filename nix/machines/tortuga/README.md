# `tortuga` install (dual boot with Windows)

This machine uses:
- One disk shared with Windows; NixOS gets the second half
- Its own 1 GiB ESP (`nixos-esp`) — Windows' ESP is left untouched
- LUKS root (`nixos-root` → `cryptroot`), ext4
- NVIDIA proprietary driver (open kernel modules)
- User `chris`, configured from the `nix/users/framework` profile
