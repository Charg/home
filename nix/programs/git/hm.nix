{
  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
        alias = {
          a = "add -p";
          ch = "diff --cached";
          fixup = "commit --amend -C HEAD";
          fpush = "push --force-with-lease";
          lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
          pr = "!f(){ gh pr view --web; }; f";
          pushb = "!f(){ BRANCH=$(git symbolic-ref --short HEAD); git push --set-upstream origin $BRANCH;}; f";
          root = "rev-parse --show-toplevel";
        };
        user = {
            email = "chris@syn.sh";
            name = "chris";
        };

        color.ui = "auto";
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
    };

    ignores = [
      "**/modules/*/.terraform.lock.hcl"
      ".DS_Store"
      ".venv"
      "venv"
    ];

    includes = [
      {
        condition = "gitdir:/Users/";
        path = "~/.gitconfig.work";
      }
    ];
  };
}
