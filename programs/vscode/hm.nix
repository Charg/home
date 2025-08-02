{
  pkgs,
  isLinux,
  isDarwin,
  ...
}:
{
  programs.vscode = {
    enable = isLinux || isDarwin;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      dracula-theme.theme-dracula
      github.copilot
      github.copilot-chat
      golang.go
      hashicorp.terraform
      jnoortheen.nix-ide
      mkhl.direnv
      ms-python.python
      ms-python.vscode-pylance
      ms-vscode-remote.remote-ssh
      oderwat.indent-rainbow
      redhat.vscode-yaml
      streetsidesoftware.code-spell-checker
      vscodevim.vim
    ];

    profiles.default.userSettings = {
      "[nix]"."editor.tabSize" = 2;
      "chat.commandCenter.enabled" = true;
      "editor.formatOnSave" = true;
      "editor.minimap.enabled" = false;
      "explorer.confirmDelete" = false;
      "files.insertFinalNewline" = true;
      "files.trimFinalNewlines" = true;
      "files.trimTrailingWhitespace" = true;
      "github.copilot.enable"."markdown" = "true";

      # telemetry
      "redhat.telemetry.enabled" = false;
      "telemetry.enableTelemetry" = false;
      "telemetry.telemetryLevel" = "off";
    };
  };
}
