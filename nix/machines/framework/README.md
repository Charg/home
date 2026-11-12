# `framework`

User `chris`, configured from the `nix/users/framework` profile.

Disk layout is in `disk-config.nix`. `root` and `nix` are separate btrfs
subvolumes from `home`, so they can be recreated on reinstall without touching
`home`.
