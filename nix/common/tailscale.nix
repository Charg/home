{
  # Joined to the headscale tailnet (see nix/machines/oci01/README.md):
  #   sudo tailscale up --login-server https://headscale.packet.fail --operator=$USER
  services.tailscale = {
    enable = true;
    openFirewall = true;
    # Loose rpfilter so exit nodes and subnet routes work
    useRoutingFeatures = "client";
  };

  networking.networkmanager.unmanaged = [ "interface-name:tailscale0" ];

  # MagicDNS needs resolved; otherwise tailscaled and NetworkManager fight
  # over /etc/resolv.conf
  services.resolved.enable = true;
}
