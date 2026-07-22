{
  config,
  pkgs,
  ...
}:

{
  programs.claude-code = {
    enable = true;

    settings = {
      permissions.defaultMode = "auto";
      model = "sonnet";
      effortLevel = "high";
      tui = "fullscreen";
      skipAutoPermissionPrompt = true;

      statusLine = {
        type = "command";
        command = "${config.home.homeDirectory}/.claude/scripts/statusline.sh";
      };
      subagentStatusLine = {
        type = "command";
        command = "${config.home.homeDirectory}/.claude/scripts/subagent-statusline.sh";
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
  };
}
