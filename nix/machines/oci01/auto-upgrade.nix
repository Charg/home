{ ... }:

# Only internet-facing host, so it doesn't wait for a manual colmena run.
# Renovate's weekly lockFileMaintenance PR bumps flake.lock; once merged, this
# rebuilds from main and applies it. Anything deployed from a branch is
# reverted to main on the next run.
{
  system.autoUpgrade = {
    enable = true;
    flake = "github:Charg/home#oci01";
    dates = "04:00";
    randomizedDelaySec = "45min";
    persistent = true;

    # Kernel and systemd updates need a reboot to take effect
    allowReboot = true;
    rebootWindow = {
      lower = "04:00";
      upper = "06:00";
    };
  };

  # Keep the 50 GB boot volume from filling with old generations
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;
}
