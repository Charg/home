{
  config,
  inputs,
  unstable-pkgs,
  currentSystemName,
  ...
}:

# Fleet agent (orbit + osquery), enrolling into kube/nuc01/fleet-config.
#
# services.orbit isn't in NixOS 26.05, so the module comes from
# nixpkgs-unstable. Its fleet-orbit (1.55.0) predates the fleetd_nix_packages
# software inventory, so the package is bumped here to 1.63.0, which also
# carries the NixOS support the nixpkgs patches used to add. Drop the import
# once the stable channel has the module, and the override once its
# fleet-orbit is >= 1.63.0.
#
# The enroll secret is per-host in secrets/fleet.enc.yaml (same value on
# every host) and must match one of Fleet's global enroll secrets.
let
  fleet-orbit =
    (unstable-pkgs.fleet-orbit.override { buildGoModule = unstable-pkgs.buildGo127Module; })
    .overrideAttrs
      (
        finalAttrs: _: {
          version = "1.63.0";
          src = unstable-pkgs.fetchFromGitHub {
            owner = "fleetdm";
            repo = "fleet";
            tag = "orbit-v${finalAttrs.version}";
            hash = "sha256-cKF1nE9kK22EfB0Ky+vp8QaBDYcZ00mwWNU9BJwWAx8=";
          };
          vendorHash = "sha256-mnjllTf4m8Kirx0TKKWzr0haA/zwiZMWYEYRifVeFpQ=";
          patches = [ ];
        }
      );
in
{
  imports = [ "${inputs.nixpkgs-unstable}/nixos/modules/services/monitoring/orbit.nix" ];

  sops.secrets.fleet-enroll-secret = {
    sopsFile = ../machines/${currentSystemName}/secrets/fleet.enc.yaml;
    restartUnits = [ "orbit.service" ];
  };

  services.orbit = {
    enable = true;
    orbitPackage = fleet-orbit;
    fleetUrl = "https://fleet.home.packet.fail";
    enrollSecretPath = config.sops.secrets.fleet-enroll-secret.path;
    # Some hosts share an SMBIOS UUID; osquery's instance id is per install.
    hostIdentifier = "instance";
  };
}
