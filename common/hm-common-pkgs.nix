{
  pkgs,
}:

[
  # CLI Tools
  pkgs.awscli2
  pkgs.bottom
  pkgs.dig
  pkgs.docker-compose
  pkgs.file
  pkgs.ghostty
  pkgs.htop
  pkgs.jq
  pkgs.kubectl
  pkgs.kube-prompt
  pkgs.kubernetes-helm
  pkgs.lsof
  pkgs.minikube
  pkgs.nixfmt-rfc-style
  pkgs.nnn
  pkgs.nodejs
  pkgs.python313
  pkgs.ripgrep
  pkgs.sqlite
  pkgs.tmux
  pkgs.yubikey-manager
  pkgs.uv
  pkgs.zoxide

  # Network Tools
  pkgs.cloudflare-warp # FIX: Flooding journal logs with weird GUI error
  pkgs.nmap
  pkgs.wireshark

  # Productivity Tools
  pkgs.lan-mouse
]
