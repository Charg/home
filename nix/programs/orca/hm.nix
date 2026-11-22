{ pkgs, ... }:

{
  home.packages = [
    pkgs.local.orca
  ];
}
