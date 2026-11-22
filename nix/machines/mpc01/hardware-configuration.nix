{
  config,
  lib,
  ...
}:
{
  boot.initrd.availableKernelModules = [
    "nvme"
    "r8169" # onboard Realtek Gigabit NIC, needed for initrd SSH LUKS unlock
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
