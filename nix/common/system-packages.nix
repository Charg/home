{ pkgs, ... }:

{
  # Packages available system-wide, regardless of which user is logged in.
  environment.systemPackages = [
    pkgs.bottom # Modern process/resource monitor (btm) - htop replacement
  ];
}
