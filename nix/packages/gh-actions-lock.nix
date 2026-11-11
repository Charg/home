{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

# gh CLI extension; not in nixpkgs. Linked into gh's extensions dir by
# common/hm-common.nix. To bump: update `version`, then rebuild and copy the
# new `hash`/`vendorHash` from the mismatch errors.
buildGoModule (finalAttrs: {
  pname = "gh-actions-lock";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-actions-lock";
    tag = "v${finalAttrs.version}";
    hash = "sha256-9jU5NmBFZayhOX8ifc+aMDhaIQ4XVPlLI/dPUoQuzNw=";
  };

  vendorHash = "sha256-MS0GDAo/COikI5LwfgNPR83MhY6fAFg+Lpmzkv86X3M=";

  subPackages = [ "cmd/gh-actions-lock" ];

  # Upstream's suite exercises git/network fixtures.
  doCheck = false;

  meta = {
    description = "gh extension that pins GitHub Actions workflow dependencies in a lockfile";
    homepage = "https://github.com/github/gh-actions-lock";
    license = lib.licenses.mit;
    mainProgram = "gh-actions-lock";
  };
})
