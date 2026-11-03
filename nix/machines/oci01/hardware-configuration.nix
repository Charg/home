{ lib, modulesPath, ... }:

# Oracle Cloud Ampere A1 VM (VM.Standard.A1.Flex), paravirtualized boot volume
# and NIC, provisioned separately with Terraform.
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_scsi"
    "xhci_pci"
    "usbhid"
  ];

  # OCI's serial console connection
  boot.kernelParams = [ "console=ttyAMA0" ];

  boot.loader.grub = {
    devices = [ "nodev" ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
