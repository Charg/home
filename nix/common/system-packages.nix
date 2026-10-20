{ pkgs, ... }:

{
  # Packages available system-wide, regardless of which user is logged in.
  environment.systemPackages = [
    pkgs.bottom # Modern process/resource monitor (btm) - htop replacement
    pkgs.pciutils # lspci
    pkgs.usbutils # lsusb
    pkgs.ghostty.terminfo # so `xterm-ghostty` resolves when SSHing between hosts
  ];
}
