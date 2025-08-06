{
  config,
  pkgs,
  lib,
  currentSystemName,
  ...
}:

{
  programs.zsh = {
    enable = true;
    autocd = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    dirHashes = {
      code = "$HOME/code";
      docs = "$HOME/Documents";
      down = "$HOME/Downloads";
      home = "$HOME/code/home";
    };

    history = {
      append = true;
      extended = true;
      size = 99999;
    };

    initContent = ''
      bindkey -v

      # https://scottspence.com/posts/speeding-up-my-zsh-shell
      DISABLE_AUTO_UPDATE="true"
      DISABLE_MAGIC_FUNCTIONS="true"
      DISABLE_COMPFIX="true"

      if [[ -d /opt/homebrew ]]; then
      	eval "$(/opt/homebrew/bin/brew shellenv)"
      fi

      . $HOME/.zsh_functions

      # PATH Updates
      PATH="$HOME/.local/bin:$PATH"
    '';

    antidote = {
      enable = true;
      plugins = [
        "ohmyzsh/ohmyzsh"
        "ohmyzsh/ohmyzsh path:lib"
        "ohmyzsh/ohmyzsh path:plugins/aws"
        "ohmyzsh/ohmyzsh path:plugins/git"
        "ohmyzsh/ohmyzsh path:plugins/helm"
        "ohmyzsh/ohmyzsh path:plugins/kubectl"
	"ohmyzsh/ohmyzsh path:plugins/magic-enter"
      ];
    };

    shellAliases = {
      _ = "sudo";
      a = "ansible";
      # ... other aliases

      nixg = "sudo nix-collect-garbage -d";
      nixrs = "sudo nixos-rebuild switch --flake ~/code/home#${currentSystemName}";
      nixrt = "sudo nixos-rebuild test --flake ~/code/home#${currentSystemName}";
      nixfc = "nix flake check ~/code/home";
    };
  };

  home.file.".zsh_functions".source = ../../programs/zsh/functions;
}
