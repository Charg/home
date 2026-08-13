{ config, ... }:
{
  programs.ripgrep = {
    enable = true;

    arguments = [
      "--hidden"
      # rg only auto-discovers ignore files named .gitignore/.ignore/.rgignore by
      # ascending the CWD's parents; an XDG-located one is never found that way,
      # so this line is what actually activates the global ignores.
      "--ignore-file=${config.xdg.configHome}/ripgrep/rgignore"
    ];
  };

  xdg.configFile."ripgrep/rgignore".source = ./rgignore;
}
