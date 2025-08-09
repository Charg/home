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
      # Enable vim mode. This works better than the home manager setting.
      bindkey -v

      # https://scottspence.com/posts/speeding-up-my-zsh-shell
      DISABLE_AUTO_UPDATE="true"
      DISABLE_MAGIC_FUNCTIONS="true"
      DISABLE_COMPFIX="true"

      # TODO: Use isDarwin to conditionally add this
      if [[ -d /opt/homebrew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi


      # TODO: Use SOPS to import these
      if [[ -f $HOME/.zsh_functions_work ]]; then
        source $HOME/.zsh_functions_work
      fi

      source $HOME/.zsh_functions

      #
      # Plugins
      #

      # Source Plugins
      source $HOME/.local/share/zplugins/magic-enter/magic-enter.plugin.zsh

      # Plugin Configuration
      zstyle ':zshzoo:magic-enter' command 'ls -alh'
      zstyle ':zshzoo:magic-enter' git-command 'git status'

      export PATH="$HOME/.local/bin:$PATH"
    '';

    # So slow. What's the point? I can source files myself.
    # antidote = {
    #   enable = true;
    #   plugins = [
    #     "ohmyzsh/ohmyzsh"
    #     "ohmyzsh/ohmyzsh path:lib"
    #     "ohmyzsh/ohmyzsh path:plugins/aws"
    #     "ohmyzsh/ohmyzsh path:plugins/git"
    #     "ohmyzsh/ohmyzsh path:plugins/helm"
    #     "ohmyzsh/ohmyzsh path:plugins/kubectl"
    #     "ohmyzsh/ohmyzsh path:plugins/magic-enter"
    #   ];
    # };

    shellAliases = {
      _ = "sudo";
      a = "ansible";
      # ... other aliases

      nixg = "sudo nix-collect-garbage -d";
      nixrs = "sudo nixos-rebuild switch --flake ~/code/home#${currentSystemName}";
      nixrt = "sudo nixos-rebuild test --flake ~/code/home#${currentSystemName}";
      nixfc = "nix flake check ~/code/home";

      # Git
      ga = "git add";
      gap = "git add --patch";
      gcm = "git commit --message";
      gfm = "git pull";
      gp = "git push";
      gs = "git stash"; # with magic-enter, maybe I move this to git stash

      # Kubernetes
      k = "kubectl";
      kga = "kubectl get all";
      kgcj = "kubectl get cronjob";
      kgj = "kubectl get job";
      kgn = "kubectl get nodes";
      kgp = "kubectl get pods";
      kgpvc = "kubectl get pvc";
      kgrs = "kubectl get replicaset";
      kgs = "kubectl get svc";
      kgss = "kubectl get statefulset";

    };
  };

  home.file = {
    ".zsh_functions".source = ../../programs/zsh/functions;
    ".local/share/zplugins/magic-enter".source = builtins.fetchGit {
      url = "https://github.com/zshzoo/magic-enter.git";
      rev = "b5a7d0a55abab268ebd94969e2df6ea867fa2cd5";
    };
  };
}
