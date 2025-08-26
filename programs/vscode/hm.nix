{
  pkgs,
  isLinux,
  isDarwin,
  ...
}:
{
  programs.vscode = {
    enable = isLinux || isDarwin;
    profiles = {
      default = {
        enableUpdateCheck = false;
        extensions = with pkgs.vscode-extensions; [
          # Appearance
          dracula-theme.theme-dracula

          # AI
          github.copilot
          github.copilot-chat

          # Languages
          golang.go
          hashicorp.terraform
          jnoortheen.nix-ide
          redhat.vscode-yaml
          ms-python.python
          ms-python.vscode-pylance

          # Tools
          mkhl.direnv
          ms-vscode-remote.remote-ssh

          # Other
          streetsidesoftware.code-spell-checker
          oderwat.indent-rainbow
          vscodevim.vim
        ];

        userSettings = {
          "chat.commandCenter.enabled" = true;
          "editor.formatOnSave" = true;
          "editor.minimap.enabled" = false;
          "explorer.confirmDelete" = false;
          "files.autoSave" = "onFocusChange";
          "files.insertFinalNewline" = true;
          "files.trimFinalNewlines" = true;
          "files.trimTrailingWhitespace" = true;
          "github.copilot.enable"."markdown" = true;

	  # indent
	  "editor.detectIndentation" = true;
	  "editor.indentSize" = 2;
	  "editor.insertSpaces" = true;
	  "editor.tabSize" = 2;

	  "[nix]" = {
	    "editor.indentSize" = 2;
            "editor.tabSize" = 2;
          };

	  "[python]" = {
	    "editor.indentSize" = 4;
            "editor.tabSize" = 4;
          };


          # vim
          "vim.easymotion" = true;
          "vim.hlsearch" = true;
          "vim.timeout" = 500;
          "vim.leader" = "<space>";

          # telemetry
          "redhat.telemetry.enabled" = false;
          "telemetry.enableTelemetry" = false;
          "telemetry.telemetryLevel" = "off";
        };
      };
    };
  };
}
