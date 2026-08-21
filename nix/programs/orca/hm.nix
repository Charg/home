{ pkgs, ... }:

{
  home.packages = [
    (pkgs.callPackage ../../packages/orca.nix { })
  ];
}
