# :house: Home
> [!NOTE]
> This repo builds upon the excellent work in Mitchell Hashimoto’s [nixos-config](https://github.com/mitchellh/nixos-config). Thanks for sharing!

TODO:
- [ ] document how tf this all works
- [ ] declarative disk setup for framework laptop
- [ ] full disk encryption for framework laptop
- [x] migrate zsh configuration to here
- [x] migrate tmux configuration to here
- [x] add macos configuration

## Layout
- `flake.nix`: the host table; each host names its `role`, its `home` setup
  (if it has Home Manager) and its system and Home Manager state versions.
- `nix/roles/`: what a machine is for (`base`, `server`, `k3s-node`, `workstation`, `wsl`, `darwin`).
- `nix/machines/<host>/`: hardware, disks and the host's own differences.
- `nix/users/<home>/`: a user's account and Home Manager config.
- `nix/common/`, `nix/programs/`: features. A system feature with a Home
  Manager half imports that half for `host.user` itself (see
  `nix/common/gnome.nix`), so enabling it is one import.
- `nix/packages/`: local packages, one `<name>.nix` or `<name>/package.nix`
  each, available to hosts as `pkgs.local.<name>` and exported as `packages`.
- `nix/lib/`: the system and Home Manager builders, overlays and flake checks.

## Commands
- `nix develop`: a shell with the tools the recipes and hooks use.
- `nix fmt`: format every Nix file.
- `nix flake check`: formatting, lint, and evaluation of every configuration.
- `nix build .#<package>`: build a local package.
- `just config-identity [base]`: which configurations a change alters
  (evaluation only).
- `just deploy <host|@tag> [goal]`, `just deploy-eval`: Colmena deploys.
- `just`: lists every recipe, including the pinned-package bumps.
- Optional: `git config diff.sopsdiffer.textconv "sops -d"` shows decrypted
  diffs for `*.enc.yaml`.

## WSL
### Creating An Image
From a linux host you can create a nixos image tarball which can be imported into WSL.

```
sudo nix run ".#nixosConfigurations.wsl.config.system.build.tarballBuilder"
```

This will produce a tarball `nixos-wsl.tar.gz` which can be copied into a windows host and imported with the following command:

```
```

## Nix Cheatsheet
[Official nixos cheatsheet](https://nixos.wiki/wiki/Cheatsheet)

### Flakes
#### Visualize your flake
`nix flake show`

#### REPL
You can load your flake into the repl to see how it's being evaluated.

```
❯ nix repl
Nix 2.24.11
Type :? for help.

nix-repl> :lf .
warning: Git tree '/home/chris/code/home' is dirty
Added 12 variables.

nix-repl> outputs.nixosConfigurations.<TAB>
```
