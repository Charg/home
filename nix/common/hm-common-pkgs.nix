{
  pkgs,
}:

[
  # CLI Tools
  pkgs.bottom
  pkgs.dig
  pkgs.file
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
  pkgs.uv
  pkgs.yubikey-manager
  pkgs.zoxide

  # Network Tools
  pkgs.nmap
  pkgs.wireshark
  pkgs.wireguard-tools

  # Desktop Apps
  pkgs.bitwarden-desktop
]
