{
  isLinux,
  isDarwin,
  lib,
  ...
}:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "~/.ssh/config.d/*" ];
    matchBlocks = {

      "*" = {
        addKeysToAgent = "yes";
        controlMaster = "auto";
        controlPath = "~/.ssh/sockets/%C";
        controlPersist = "10m";
        forwardAgent = false;
        identitiesOnly = true;
      };

      "github.com" = {
        controlMaster = "auto";
        controlPath = "~/.ssh/sockets/%C";
        controlPersist = "10m";
        hostname = "github.com";
        identitiesOnly = true;
        identityFile = "~/.ssh/github";
        user = "git";
      }
      // lib.optionalAttrs isDarwin {
        identityAgent = "~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
      };

    };
  };

  services.ssh-agent = {
    enable = true;
  };

  # ensure GUI apps and services know about the the ssh-agent socket
  systemd.user.sessionVariables = {
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/ssh-agent";
  };

  home.file.".ssh/config.d/.keep".text = "# Managed by Home Manager";
  home.file.".ssh/sockets/.keep".text = "# Managed by Home Manager";
}
