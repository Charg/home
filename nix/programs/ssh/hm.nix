{
  isLinux,
  ...
}:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "~/.ssh/config.d/*" ];
    settings = {

      "*" = {
        AddKeysToAgent = "yes";
        ControlMaster = "auto";
        ControlPath = "~/.ssh/sockets/%C";
        ControlPersist = "10m";
        ForwardAgent = false;
        IdentitiesOnly = true;
        ServerAliveCountMax = 3;
        ServerAliveInterval = 30;
      };

      "github.com" = {
        ControlMaster = "auto";
        ControlPath = "~/.ssh/sockets/%C";
        ControlPersist = "10m";
        HostName = "github.com";
        IdentitiesOnly = true;
        IdentityFile = "~/.ssh/github";
        User = "git";
      };

      "mpc00-unlock" = {
        HostName = "192.168.74.11";
        Port = 2222;
        User = "root";
        UserKnownHostsFile = "~/.ssh/known_hosts.d/mpc00";
      };

      "mpc00" = {
        HostName = "192.168.74.11";
        Port = 22;
        User = "nixos";
        UserKnownHostsFile = "~/.ssh/known_hosts.d/mpc00";
      };

      "mpc01-unlock" = {
        HostName = "192.168.74.12";
        Port = 2222;
        User = "root";
        UserKnownHostsFile = "~/.ssh/known_hosts.d/mpc01";
      };

      "mpc01" = {
        HostName = "192.168.74.12";
        Port = 22;
        User = "nixos";
        UserKnownHostsFile = "~/.ssh/known_hosts.d/mpc01";
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
    [192.168.74.11]:2222 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC7XXWkYl1IaGq3ZSVF0xiS5oranQAS/Yr77tH8Cx9w8
    192.168.74.11 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC7XXWkYl1IaGq3ZSVF0xiS5oranQAS/Yr77tH8Cx9w8
  '';

  home.file.".ssh/known_hosts.d/mpc01".text = ''
    [192.168.74.12]:2222 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPrBTt1ILjEDGteqTAtIAkQBHNYHfDOdnBWbPb2SXVi2
    192.168.74.12 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPrBTt1ILjEDGteqTAtIAkQBHNYHfDOdnBWbPb2SXVi2
  '';
}
