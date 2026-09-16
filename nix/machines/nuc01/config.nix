{
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./firewall.nix
    ../../common/system-packages.nix
  ];

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../../common/keys/home.pub)
    ];
  };

  users.motd = ''
    Welcome to NUC01!
  '';

  security.sudo.wheelNeedsPassword = false;
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Increase maximum socket receive/send buffer sizes to 8MB
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 8388608;
    "net.core.wmem_max" = 8388608;
  };

  boot.kernelParams = [ "ip=dhcp" ];
  boot.initrd.network.enable = true;
  boot.initrd.network.ssh = {
    enable = true;
    port = 2222;
    shell = "/bin/cryptsetup-askpass";
    authorizedKeys = [
      (builtins.readFile ../../common/keys/home.pub)
    ];
    hostKeys = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
  };

  services.openssh.enable = true;
  system.stateVersion = "25.11";

  networking.hostName = "nuc01";

  services.openiscsi = {
    enable = true;
    name = "iqn.2005-03.org.open-iscsi:nuc01";
  };

  # The synology-csi node plugin doesn't call iscsiadm directly - it chroots
  # into the bind-mounted host root and re-execs "iscsiadm" against
  # PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  # (see chroot/chroot.sh in the synology-csi source). NixOS has no /usr/bin
  # or /sbin - installed packages only live under /run/current-system/sw/bin
  # - so services.openiscsi.enable alone isn't enough; the chroot still
  # can't find the binary. Symlink it into the one FHS path the chroot
  # script checks first.
  systemd.tmpfiles.rules = [
    "d /usr/local/sbin 0755 root root -"
    "L+ /usr/local/sbin/iscsiadm - - - - ${pkgs.openiscsi}/bin/iscsiadm"
  ];

  services.k3s.clusterInit = true;
}
