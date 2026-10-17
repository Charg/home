{ pkgs, inputs, ... }:
{
  programs.vicinae = {
    enable = true;
    package = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
    systemd.enable = true;
  };
}
