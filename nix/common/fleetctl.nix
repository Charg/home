# fleetctl pinned to the Fleet server version in kube/nuc01/fleet/values.yaml
# (nixpkgs lags behind). Bump the two together; drop this once
# unstable-pkgs.fleetctl catches up.
{ unstable-pkgs }:

(unstable-pkgs.fleetctl.override { buildGoModule = unstable-pkgs.buildGo127Module; }).overrideAttrs
  (
    finalAttrs: _: {
      version = "4.94.0";
      src = unstable-pkgs.fetchFromGitHub {
        owner = "fleetdm";
        repo = "fleet";
        tag = "fleet-v${finalAttrs.version}";
        hash = "sha256-EWXD1UW8xQ6vHFOdvrmx8fIilpRpq3wm1vttWRaZ0K0=";
      };
      vendorHash = "sha256-YtQFUaMsf++rKomkakN8JoxdkXYMOwVZw0nRBTwW6/w=";
    }
  )
