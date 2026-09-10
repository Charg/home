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

      "mpc00-unlock" = {
        hostname = "192.168.73.228";
        port = 2222;
        user = "root";
        userKnownHostsFile = "~/.ssh/known_hosts.d/mpc00";
      };

      "mpc00" = {
        hostname = "192.168.73.228";
        port = 22;
        user = "nixos";
        userKnownHostsFile = "~/.ssh/known_hosts.d/mpc00";
      };

      "mpc01-unlock" = {
        hostname = "192.168.74.12";
        port = 2222;
        user = "root";
        userKnownHostsFile = "~/.ssh/known_hosts.d/mpc01";
      };

      "mpc01" = {
        hostname = "192.168.74.12";
        port = 22;
        user = "nixos";
        userKnownHostsFile = "~/.ssh/known_hosts.d/mpc01";
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

  home.file.".ssh/known_hosts.d/mpc00".text = ''
    [192.168.73.228]:2222 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC7XXWkYl1IaGq3ZSVF0xiS5oranQAS/Yr77tH8Cx9w8
    192.168.73.228 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC7XXWkYl1IaGq3ZSVF0xiS5oranQAS/Yr77tH8Cx9w8
  '';

  home.file.".ssh/known_hosts.d/mpc01".text = ''
    [192.168.74.12]:2222 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPrBTt1ILjEDGteqTAtIAkQBHNYHfDOdnBWbPb2SXVi2
    192.168.74.12 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPrBTt1ILjEDGteqTAtIAkQBHNYHfDOdnBWbPb2SXVi2
  '';
}
