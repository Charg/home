{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      aws.disabled = false;
      battery.disabled = false;
      direnv.disabled = false;
      terraform.disabled = false;

      kubernetes.disabled = false;
      kubernetes = {
        contexts = [
          {
            context_pattern = "prod";
            style = "red";
          }
        ];
      };

      # Dracula Theme https://draculatheme.com/starship
      aws.style = "bold #ffb86c";
      cmd_duration.style = "bold #f1fa8c";
      directory.style = "bold #50fa7b";
      hostname.style = "bold #ff5555";
      git_branch.style = "bold #ff79c6";
      git_status.style = "bold #ff5555";
      username = {
        format = "[$user]($style) on ";
        style_user = "bold #bd93f9";
      };
      character = {
        success_symbol = "[>](bold #f8f8f2)";
        error_symbol = "[>](bold #ff5555)";
      };

    };
  };
}
