{
  isLinux,
  ...
}:
{
  programs.ssh = {
    enable = true;
    includes = ["~/.ssh/config.d/*"];
    matchBlocks = {

      "*" = {
        addKeysToAgent = "yes";
        controlMaster = "auto";
        controlPath = "~/.ssh/sockets/S.%r@%h:%p";
        controlPersist = "10m";
        forwardAgent = false;
      };

      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/github";
        identitiesOnly = true;
      };

    };
  };

  services.ssh-agent = {
    enable = isLinux;
  };

  home.file.".ssh/config.d/.keep".text = "# Managed by Home Manager";
  home.file.".ssh/sockets/.keep".text = "# Managed by Home Manager";
}
