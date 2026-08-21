{ pkgs, ... }:

{
  home.packages = [
    (pkgs.callPackage ../../packages/agent-orchestrator.nix { })
  ];
}
