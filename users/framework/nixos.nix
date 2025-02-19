{ pkgs, inputs, ... }:

{
  # Add ~/.local/bin to PATH
  environment.localBinInPath = true;

  # setting this there to work with the "shell" directive below
  programs.zsh.enable = true;

  users.users.framework= {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.zsh;
    hashedPassword = "$6$LsYSVIubO9ddl8lB$zGowqj8q0YLJZpGpKPjCf5wIDE6AnoOvOdPZIpiP213Dus0niljEDMQz0TJX3COGc70q2OHnZ.nut824iNiRo.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO6/6RczXJeevJqfj9xx38UKd4qlUaytq1P6lLcu9WhY"
    ];
  };
}
