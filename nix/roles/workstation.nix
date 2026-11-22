# Desktop Linux machines: GNOME, PipeWire, Docker and VirtualBox, telemetry
# and fleet enrolment.
{ pkgs, ... }:
{
  # Order follows the per-host configs this role replaced; module order sets
  # list-merge order.
  imports = [
    ../common/alloy.nix
    ../common/bluetooth.nix
    ../common/fonts.nix
    ../common/gnome.nix
    ../common/nix-ld.nix
    ../common/system-packages.nix # also via base; listed for its position
    ../common/ca-blacklist.nix
    ../common/openssh-hardening.nix
    ../common/fleetd.nix
    ../common/sops-user-password.nix
    ../common/rbw.nix
    ../common/tailscale.nix
    ../common/docker-local-ports.nix
    ./base.nix
  ];

  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  # Docker, VirtualBox, etc. create a NetworkManager connection profile for
  # every bridge/veth they own. Let them manage their own interfaces instead.
  systemd.services.NetworkManager-wait-online.enable = false;
  networking.networkmanager.unmanaged = [
    "interface-name:docker*"
    "interface-name:br-*"
    "interface-name:veth*"
    "interface-name:vboxnet*"
  ];

  # No public fallback resolvers; use only the DNS servers handed out by the network.
  services.resolved.settings.Resolve.FallbackDNS = [ ];

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_29;
  # Weekly `docker system prune -f`: networks, images and stopped containers.
  virtualisation.docker.autoPrune.enable = true;

  virtualisation.virtualbox.host.enable = true;
  # Don't bring up vboxnet0 at boot; VirtualBox creates host-only interfaces
  # itself when a VM that uses one starts.
  virtualisation.virtualbox.host.addNetworkInterface = false;

  security.sudo.wheelNeedsPassword = false;
  # PipeWire uses the realtime scheduler through rtkit.
  security.rtkit.enable = true;

  # Smart card daemon, for YubiKey operations.
  services.pcscd.enable = true;

  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    pulse.enable = true;
  };

  services.xserver = {
    enable = true;
    excludePackages = with pkgs; [ xterm ];
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.printing.enable = false;
  services.openssh.enable = true;
  services.fwupd.enable = true;

  services.journald.extraConfig = ''
    SystemMaxUse=1G
  '';

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      keep-outputs = true;
      keep-derivations = true;
    };
    optimise.automatic = true;
  };

  # Weekly GC of old generations and unreferenced store paths.
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 14d --keep 5";
    };
  };
}
