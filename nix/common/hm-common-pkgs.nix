{
  pkgs,
  inputs,
  unstable-pkgs,
}:

[
  # CLI Tools
  pkgs.age
  pkgs.bottom
  pkgs.codex # OpenAI Codex
  pkgs.crane # Tools for interacting with remote images and registries including crane and gcrane
  pkgs.dig
  pkgs.dive # Tool for exploring each layer in a docker image
  pkgs.file
  pkgs.gh # Github CLI tools
  pkgs.git-crypt
  pkgs.glow # Render markdown on the CLI, with pizzazz! - https://github.com/charmbracelet/glow
  pkgs.grype # Vulnerability scanner for container images and filesystems
  pkgs.htop
  pkgs.jq
  pkgs.just # Handy way to save and run project-specific commands
  pkgs.kube-prompt
  pkgs.lsof
  pkgs.mermaid-cli # Renders mermaid diagrams to PNG/SVG (mmdc)
  pkgs.minikube
  pkgs.nh # Yet another Nix CLI helper - https://github.com/nix-community/nh
  pkgs.nixd # Nix LSP
  pkgs.nixfmt
  pkgs.nnn
  pkgs.nodejs
  pkgs.openssl
  pkgs.python313
  pkgs.sops
  pkgs.sqlite-interactive # compiled with quality of additions like readline support
  pkgs.trivy # Simple and comprehensive vulnerability scanner for containers, suitable for CI
  pkgs.unzip
  pkgs.uv
  pkgs.whois
  pkgs.yubikey-manager

  inputs.colmena.packages.${pkgs.stdenv.hostPlatform.system}.colmena # NixOS multi-machine deployment tool
  unstable-pkgs.mise # A tool to manage multiple versions of a CLI tool, written in Rust
  unstable-pkgs.prek # Better `pre-commit`, re-engineered in Rust - https://github.com/j178/prek
  unstable-pkgs.wtp # Git worktree CLI with automated setup, branch tracking, and navigation.

  # Network Tools
  pkgs.ipcalc
  pkgs.nmap
  pkgs.wireguard-tools
  pkgs.wireshark

  # Desktop Apps
  pkgs.bitwarden-desktop
  pkgs.dbeaver-bin
]
