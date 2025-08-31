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
```
❯ nix flake show
git+file:///home/framework/code/home
└───nixosConfigurations
    ├───framework: NixOS configuration
    └───wsl: NixOS configuration
```

#### Check
The following command will check that your flakes are in working order.

`nix flake check`

#### REPL
You can load your flake into the repl to see how it's being evaluated.

```
❯ nix repl
Nix 2.24.11
Type :? for help.

nix-repl> :lf .
warning: Git tree '/home/framework/code/home' is dirty
Added 12 variables.

nix-repl> nix-repl> outputs.nixosConfigurations.<TAB>
outputs.nixosConfigurations.framework13  outputs.nixosConfigurations.wsl
```
