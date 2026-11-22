# Every NixOS host.
{ ... }:
{
  imports = [
    ../common/system-packages.nix
    ../common/lab.nix
  ];
}
