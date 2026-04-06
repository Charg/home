# Colmena Managed

This directory contains Colmena-specific managed deployment configuration.

- `managed.nix`: defines the Colmena-managed node set (`inputs.colmena.lib.makeHive`) and deployment metadata.

## Why this file exists

`managed.nix` keeps Colmena deployment definitions separate from standard `flake.nix` outputs.
This avoids custom top-level flake outputs while still keeping Colmena configuration modular.

## Usage

Use this file directly with Colmena via `--config`.

```zsh
colmena --config ./nix/colmena/managed.nix eval -E '{ nodes, ... }: builtins.attrNames nodes'
colmena --config ./nix/colmena/managed.nix apply --on nuc01
```

Or with `nix run`:

```zsh
nix run github:zhaofengli/colmena -- --config ./nix/colmena/managed.nix eval -E '{ nodes, ... }: builtins.attrNames nodes'
nix run github:zhaofengli/colmena -- --config ./nix/colmena/managed.nix apply --on nuc01
```

## Validate

From repository root:

```zsh
nix flake check
```
