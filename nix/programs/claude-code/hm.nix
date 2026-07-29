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
      model = "opusplan";
      permissions.defaultMode = "auto";
      preferredNotifChannel = "ghostty";
      skipAutoPermissionPrompt = true;
      teammateMode = "tmux";
      tui = "fullscreen";

      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";

        # Treats a 1M context model as if it only had 300K tokens
        # Compact at 100% of 300K tokens
        CLAUDE_CODE_AUTO_COMPACT_WINDOW = "300000";
        CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "100";
      };

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
