{ lib, ... }:

let
  forcedCommand = "systemctl default";
in
{
  boot.kernelParams = [ "ip=dhcp" ];
  boot.initrd.network.enable = true;
  boot.initrd.network.ssh = {
    enable = true;
    port = 2222;
    # Any login runs the passphrase prompt and continues boot; no initrd shell.
    authorizedKeys = [
      ''command="${forcedCommand}" ${lib.trim (builtins.readFile ./keys/home.pub)}''
    ];
    hostKeys = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
  };
}
