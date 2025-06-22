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
    defaultKeymap = "viins";

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

    # Note: the source path is relative to THIS file now.
    # However, since you point to the root of the repo, an absolute path
    # derived from `config.home.homeDirectory` is more robust.
    # For now, let's keep it simple.
    initContent = ''
      . $HOME/.zsh_functions
    '';

    antidote = {
      enable = true;
      plugins = [
        "ohmyzsh/ohmyzsh"
        "ohmyzsh/ohmyzsh path:lib/clipboard.zsh"
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
}
