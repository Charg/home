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
      #
      # MISC
      #
      _ = "sudo";
      a = "ansible";
      l = "ls";
      py = "python3";
      reboot = "sudo reboot";
      shut = "sudo shutdown -h now";
      weather = "curl wttr.in/sf";

      #
      # AWS
      #
      asl = "aws sso login";

      #
      # Git
      #
      ga = "git add";
      gap = "git add --patch";
      gbls = "git branch -l --sort=-committerdate --format='%(authordate:short) %(color:yellow)%(refname:short) %(color:blue)%(subject)%(color:reset)  (%(color:green)%(committerdate:relative)%(color:reset))'";
      gcb = "git checkout -b";
      gch = "git ch";
      gcm = "git commit --message";
      gco = "git checkout";
      gfm = "git pull";
      git_show_tag_by_date = "git log --tags --simplify-by-decoration --pretty='format:%ai %d'";
      gp = "git push";
      gpb = "git pushb";
      gs = "git stash";
      gtr = "cd $(git rev-parse --show-cdup)";

      #
      # Kubernetes
      #
      k = "kubectl";
      kc = "k get configmap -o go-template='{{ range \$key, \$value := .data }}{{ printf \"%s:\\n%s\\n\\n\" \$key \$value }}{{ end }}'";
      kga = "kubectl get all";
      kgcj = "kubectl get cronjob";
      kgj = "kubectl get job";
      kgn = "kubectl get nodes";
      kgp = "kubectl get pods";
      kgpvc = "kubectl get pvc";
      kgrs = "kubectl get replicaset";
      kgs = "kubectl get svc";
      kgss = "kubectl get statefulset";
      ks = "k get secrets -o go-template='{{ range \$key, \$value := .data }}{{ printf \"%s:\\n%s\\n\\n\" \$key (\$value | base64decode) }}{{ end }}'";

      #
      # Nix
      #
      nixg = "sudo nix-collect-garbage -d";
      nixrs = "sudo nixos-rebuild switch --flake ~/code/home#${currentSystemName}";
      nixrt = "sudo nixos-rebuild test --flake ~/code/home#${currentSystemName}";
      nixdr = "sudo darwin-rebuild switch --flake ~/code/home#${currentSystemName}";
      nixfc = "nix flake check ~/code/home";
    };

    shellGlobalAliases = {
      B6 = "base64 -d";
      CP = "| pbcopy"; # switch this based on isDarwin||isLinux
      X5 = "openssl x509 -noout -text";
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
