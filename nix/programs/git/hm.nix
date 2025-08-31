{
  programs.git = {
    enable = true;
    delta.enable = true;
    lfs.enable = true;
    userEmail = "chris@syn.sh";
    userName = "chris";

    aliases = {
      a = "add -p";
      ch = "diff --cached";
      fixup = "commit --amend -C HEAD";
      fpush = "push --force-with-lease";
      lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      pr = "!f(){ gh pr view --web; }; f";
      pushb = "!f(){ BRANCH=$(git symbolic-ref --short HEAD); git push --set-upstream origin $BRANCH;}; f";
      root = "rev-parse --show-toplevel";
    };

    ignores = [
      "**/modules/*/.terraform.lock.hcl"
      ".DS_Store"
      ".venv"
      "venv"
    ];

    extraConfig = {
      color.ui = "auto";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

}
