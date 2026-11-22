# fleetctl pinned to the Fleet server version in kube/nuc01/fleet/values.yaml
# (nixpkgs lags behind). Bump the two together; drop this once
# pkgs.unstable.fleetctl catches up.
{ unstable }:

(unstable.fleetctl.override { buildGoModule = unstable.buildGo127Module; }).overrideAttrs (
  finalAttrs: _: {
    version = "4.94.0";
    src = unstable.fetchFromGitHub {
      owner = "fleetdm";
      repo = "fleet";
      tag = "fleet-v${finalAttrs.version}";
      hash = "sha256-EWXD1UW8xQ6vHFOdvrmx8fIilpRpq3wm1vttWRaZ0K0=";
    };
    vendorHash = "sha256-YtQFUaMsf++rKomkakN8JoxdkXYMOwVZw0nRBTwW6/w=";
  }
)
