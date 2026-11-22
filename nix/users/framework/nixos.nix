{
  pkgs,
  inputs,
  host,
  ...
}:

{
  # Add ~/.local/bin to PATH
  environment.localBinInPath = true;

  # setting this there to work with the "shell" directive below
  programs.zsh.enable = true;

  environment.systemPackages = [ pkgs.android-tools ];

  users.users.${host.user} = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "vboxusers"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO6/6RczXJeevJqfj9xx38UKd4qlUaytq1P6lLcu9WhY"
    ];
  };
}
