{
  pkgs,
}:

[
  # CLI Tools
  pkgs.bottom
  pkgs.crane # Tools for interacting with remote images and registries including crane and gcrane
  pkgs.dig
  pkgs.dive # Tool for exploring each layer in a docker image
  pkgs.dockle # Container Image Linter for Security
  pkgs.file
  pkgs.grype # Vulnerability scanner for container images and filesystems
  pkgs.htop
  pkgs.jq
  pkgs.kube-prompt
  pkgs.lsof
  pkgs.minikube
  pkgs.nh # Yet another Nix CLI helper - https://github.com/nix-community/nh
  pkgs.nixfmt-rfc-style
  pkgs.nnn
  pkgs.nodejs
  pkgs.python313
  pkgs.ripgrep
  pkgs.sqlite
  pkgs.tmux
  pkgs.trivy # Simple and comprehensive vulnerability scanner for containers, suitable for CI
  pkgs.unzip
  pkgs.uv
  pkgs.whois
  pkgs.yubikey-manager
  pkgs.zoxide

  # Network Tools
  pkgs.nmap
  pkgs.wireshark
  pkgs.wireguard-tools

  # Desktop Apps
  pkgs.bitwarden-desktop
]
