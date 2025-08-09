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

      # TODO: Can I check if `isDarwin` and add this conditionally?
      if [[ -d /opt/homebrew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi


      # TODO: Once I get SOPS working import these functions/aliases into the repo
      if [[ -f $HOME/.zsh_functions_work ]]; then
        source $HOME/.zsh_functions_work
      fi

      source $HOME/.zsh_functions

      # Load Plugins
      source $HOME/.local/share/zplugins/magic-enter/magic-enter.plugin.zsh

      # Plugin Configuration
      zstyle ':zshzoo:magic-enter' command 'ls -alh'
      zstyle ':zshzoo:magic-enter' git-command 'git status'

      #
      # Alias Configuration
      #

      # Git
      alias ga='git add'
      alias gap='git add --patch'
      alias gcm='git commit --message'
      alias gfm='git pull'
      alias gp='git push'
      alias gs='git stash' # with magic-enter, maybe I move this to git stash

      # Kubernetes
      alias k='kubectl'
      alias kgp='kubectl get pods'
      alias kgs='kubectl get svc'
      alias kgn='kubectl get nodes'

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
