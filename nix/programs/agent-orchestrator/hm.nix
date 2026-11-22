{ pkgs, ... }:

{
  home.packages = [
    pkgs.local.agent-orchestrator
  ];
}
