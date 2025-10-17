{
  isLinux,
  ...
}:
{
  programs.ssh = {
    enable = true;
    controlMaster = "auto";
    controlPath = "~/.ssh/sockets/S.%r@%h:%p";
    controlPersist = "10m";
    addKeysToAgent = "yes";
    forwardAgent = false;
    includes = ["~/.ssh/config.d/*"];
    matchBlocks = {
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
