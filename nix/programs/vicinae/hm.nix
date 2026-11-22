{ pkgs, ... }:
{
  programs.vicinae = {
    enable = true;
    package = pkgs.unstable.vicinae;
    systemd.enable = true;
  };
}
