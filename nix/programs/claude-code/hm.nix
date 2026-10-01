{
  config,
  pkgs,
  ...
}:

{
  programs.claude-code = {
    enable = true;

    skillsDir = ../../common/skills;

    settings = {
      autoCompactEnabled = true;
      effortLevel = "auto";
      model = "opus";
      outputStyle = "terse";
      permissions.defaultMode = "auto";
      permissions.deny = [
        # AWS
        "Bash(aws * delete-*)"
        "Bash(aws * terminate-*)"
        "Bash(aws * deregister-*)"
        "Bash(aws * purge-*)"
        "Bash(aws * remove-*)"
        "Bash(aws * revoke-*)"
        "Bash(aws * disable-*)"
        "Bash(aws * schedule-key-deletion*)"
        "Bash(aws * put-bucket-policy*)"
        "Bash(aws * put-key-policy*)"
        "Bash(aws * update-assume-role-policy*)"
        "Bash(aws s3 rb *)"
        "Bash(aws s3 rm *)"
        "Bash(aws s3 mv *)"
        "Bash(aws s3 sync * --delete*)"
        "Bash(aws iam create-access-key*)"
        "Bash(aws iam attach-*)"
        "Bash(aws iam put-*)"

        # Terraform / Terragrunt / OpenTofu
        "Bash(terraform destroy*)"
        "Bash(terraform force-unlock*)"
        "Bash(terraform state rm*)"
        "Bash(terraform state push*)"
        "Bash(tofu destroy*)"
        "Bash(tofu force-unlock*)"
        "Bash(tofu state rm*)"
        "Bash(tofu state push*)"
        "Bash(terragrunt destroy*)"
        "Bash(terragrunt force-unlock*)"
        "Bash(terragrunt state rm*)"
        "Bash(terragrunt state push*)"
        "Bash(terragrunt run-all destroy*)"
        "Bash(terragrunt run destroy*)"
        "Bash(terragrunt * --all destroy*)"
        "Bash(terragrunt * -auto-approve*)"
        "Bash(terragrunt * --non-interactive*)"

        # kubectl
        "Bash(kubectl delete*)"
        "Bash(kubectl drain*)"
        "Bash(kubectl rollout undo*)"
        "Bash(kubectl config delete-*)"
        "Bash(k delete*)"
        "Bash(k drain*)"

        # Helm
        "Bash(helm uninstall*)"
        "Bash(helm delete*)"
        "Bash(helm repo remove*)"
        "Bash(helm plugin uninstall*)"

        # Git
        "Bash(git push --force*)"
        "Bash(git push -f*)"
        "Bash(git push * --force*)"
        "Bash(git push * -f *)"
        "Bash(git push * --delete*)"
        "Bash(git reset --hard*)"
        "Bash(git clean*)"
        "Bash(git checkout -- *)"
        "Bash(git checkout .)"
        "Bash(git restore .)"
        "Bash(git restore --staged --worktree*)"
        "Bash(git branch -D*)"
        "Bash(git branch --delete --force*)"
        "Bash(git tag -d*)"
        "Bash(git stash drop*)"
        "Bash(git stash clear*)"
        "Bash(git reflog expire*)"
        "Bash(git reflog delete*)"
        "Bash(git gc --prune*)"
        "Bash(git filter-branch*)"
        "Bash(git filter-repo*)"
        "Bash(git update-ref -d*)"
        "Bash(git commit * --no-verify*)"
        "Bash(git push * --no-verify*)"
        "Bash(git config --global*)"
        "Bash(git config --system*)"
        "Bash(git rebase --root*)"

        # GitHub
        "Bash(gh repo delete*)"
        "Bash(gh repo archive*)"
        "Bash(gh release delete*)"
        "Bash(gh secret *)"
        "Bash(gh variable delete*)"
        "Bash(gh auth logout*)"
        "Bash(gh auth token*)"
        "Bash(gh ssh-key *)"
        "Bash(gh gpg-key *)"
        "Bash(gh api * -X DELETE*)"
        "Bash(gh api * --method DELETE*)"

        # Filesystem / system
        "Bash(rm -rf *)"
        "Bash(rm -fr *)"
        "Bash(rm -r -f *)"
        "Bash(rm -f -r *)"
        "Bash(dd *)"
        "Bash(mkfs*)"
        "Bash(fdisk *)"
        "Bash(parted *)"
        "Bash(diskutil erase*)"
        "Bash(diskutil partition*)"
        "Bash(diskutil apfs delete*)"
        "Bash(diskutil secureErase*)"
        "Bash(shred *)"
        "Bash(chmod -R 777*)"
        "Bash(chmod -R 000*)"
        "Bash(chown -R *)"
        "Bash(chmod * /)"
        "Bash(chmod * ~)"
        "Bash(mv * /dev/null*)"
        "Bash(> /dev/*)"
        "Bash(kill -9 -1*)"
        "Bash(killall *)"
        "Bash(pkill -9*)"
        "Bash(shutdown*)"
        "Bash(reboot*)"
        "Bash(halt*)"
        "Bash(poweroff*)"
        "Bash(systemctl poweroff*)"
        "Bash(systemctl reboot*)"
        "Bash(crontab -r*)"
        "Bash(csrutil *)"
        "Bash(spctl --master-disable*)"
        "Bash(defaults delete*)"
        "Bash(:(){ :|:& };:*)"

        # Pipe-to-shell
        "Bash(curl * | sh*)"
        "Bash(curl * | bash*)"
        "Bash(curl * | zsh*)"
        "Bash(curl * | sudo*)"
        "Bash(wget * | sh*)"
        "Bash(wget * | bash*)"
        "Bash(wget * | sudo*)"
        "Bash(eval \"$(curl*)"

        # Secrets and credentials
        "Read(~/.ssh/**)"
        "Read(~/.aws/credentials)"
        "Read(~/.aws/sso/**)"
        "Read(~/.gnupg/**)"
        "Read(~/.kube/config)"
        "Read(~/.config/gh/hosts.yml)"
        "Read(~/.netrc)"
        "Read(~/.docker/config.json)"
        "Edit(~/.ssh/**)"
        "Edit(~/.aws/**)"
        "Edit(~/.gnupg/**)"
        "Edit(~/.kube/**)"
        "Edit(~/.zshrc)"
        "Edit(~/.zprofile)"
        "Edit(~/.bashrc)"
        "Edit(~/.bash_profile)"
        "Edit(~/.profile)"
        "Edit(/etc/**)"
      ];
      permissions.ask = [
        # Terraform / Terragrunt / OpenTofu
        "Bash(terraform apply*)"
        "Bash(terraform import*)"
        "Bash(terraform taint*)"
        "Bash(terraform untaint*)"
        "Bash(terraform state mv*)"
        "Bash(terraform workspace delete*)"
        "Bash(tofu apply*)"
        "Bash(tofu import*)"
        "Bash(tofu taint*)"
        "Bash(tofu state mv*)"
        "Bash(terragrunt apply*)"
        "Bash(terragrunt import*)"
        "Bash(terragrunt taint*)"
        "Bash(terragrunt state mv*)"
        "Bash(terragrunt run-all apply*)"
        "Bash(terragrunt run apply*)"
        "Bash(terragrunt * --all apply*)"

        # kubectl
        "Bash(kubectl cordon*)"
        "Bash(kubectl taint*)"
        "Bash(kubectl replace*)"
        "Bash(kubectl patch*)"
        "Bash(kubectl scale*)"
        "Bash(kubectl apply*)"
        "Bash(kubectl edit*)"
        "Bash(kubectl exec*)"
        "Bash(kubectl rollout restart*)"
        "Bash(kubectl config set*)"
        "Bash(k apply*)"
        "Bash(k patch*)"
        "Bash(k replace*)"
        "Bash(k scale*)"
        "Bash(k edit*)"
        "Bash(k exec*)"
        "Bash(kustomize * | kubectl*)"

        # Helm
        "Bash(helm rollback*)"
        "Bash(helm install*)"
        "Bash(helm upgrade*)"

        # Privilege escalation
        "Bash(sudo *)"
        "Bash(su *)"
        "Bash(doas *)"
      ];
      preferredNotifChannel = "ghostty";
      skipAutoPermissionPrompt = true;
      teammateMode = "in-process";
      tui = "fullscreen";
      askUserQuestionTimeout = "never";

      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        DISABLE_AUTOUPDATER = "1";

        # Treats a 1M context model as if it only had 300K tokens
        # Compact at 100% of 300K tokens
        CLAUDE_CODE_AUTO_COMPACT_WINDOW = "300000";
        CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "100";

        CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS = "10";
        CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = "1";
        CLAUDE_CODE_DISABLE_ERROR_REPORTING = "1";
        CLAUDE_CODE_DISABLE_FEEDBACK_COMMAND = "1";
        CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
      };

      statusLine = {
        type = "command";
        command = "~/.claude/scripts/statusline.sh";
      };

      subagentStatusLine = {
        type = "command";
        command = "~/.claude/scripts/subagent-statusline.sh";
      };
    };
  };

  home.file = {
    ".claude/scripts/statusline.sh" = {
      source = ./statusline.sh;
      executable = true;
    };
    ".claude/scripts/subagent-statusline.sh" = {
      source = ./subagent-statusline.sh;
      executable = true;
    };
    ".claude/output-styles" = {
      source = ./output-styles;
      recursive = true;
    };
  };
}
