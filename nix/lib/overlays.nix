{ inputs }:

let
  # Pulls a single package forward from nixpkgs-unstable, globally, for every
  # `pkgs.<name>` reference. Only worth it when something needs the override
  # to apply implicitly (e.g. a module that reaches for `pkgs.foo` on its
  # own) or as a base to build further overrides on (see claude-code below).
  # A module that references the package directly can just take `unstable-pkgs`
  # as an argument (see nix/lib/mksystem.nix) and use `unstable-pkgs.<name>`
  # instead of adding an overlay here.
  unstableOverlay =
    packageName:
    (
      final: prev:
      let
        unstable = import inputs.nixpkgs-unstable {
          system = final.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        };
      in
      {
        ${packageName} = unstable.${packageName};
      }
    );
in
[
  (final: prev: {
    tmux = prev.tmux.overrideAttrs (oldAttrs: rec {
      version = "3.6a";
      src = prev.fetchFromGitHub {
        owner = "tmux";
        repo = "tmux";
        rev = version;
        hash = "sha256-VwOyR9YYhA/uyVRJbspNrKkJWJGYFFktwPnnwnIJ97s=";
      };
    });
  })

  (unstableOverlay "claude-code")

  # nixpkgs-unstable still lags Anthropic's own binary releases by days-to-weeks.
  # Anthropic publishes every version straight to GCS with a manifest.json of
  # per-platform checksums (same source nixpkgs' update.sh pulls from), so pin
  # directly to that instead of waiting on the next nixpkgs bump. To refresh:
  #   curl -fsSL "$BASE_URL/latest"                    # -> current version
  #   curl -fsSL "$BASE_URL/<version>/manifest.json"   # -> per-platform checksums
  # and update `version`/`checksums` below to match.
  (final: prev: {
    claude-code = prev.claude-code.overrideAttrs (
      old:
      let
        version = "2.1.287";
        baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
        checksums = {
          "darwin-arm64" = "6eab8333fe2121553100d8f40bfada384a3e989b94f947e18ba6677a6fcb41ea";
          "darwin-x64" = "f1863213e4f55aaadc2e6ee617f934ada29930e5de4c5e5f8f9e34a0d594fdd7";
          "linux-arm64" = "e4daf793d1e74fb0d9874dd09e98690bbfd7be515f78a87fd05b9e2b4bb33b03";
          "linux-x64" = "3920489a5109cff5786a1a392c25277408ff22bc796d5edb9c16a60e5a1718f0";
        };
        platformKey = "${final.stdenv.hostPlatform.node.platform}-${final.stdenv.hostPlatform.node.arch}";
      in
      {
        inherit version;
        src = final.fetchurl {
          url = "${baseUrl}/${version}/${platformKey}/claude";
          sha256 = checksums.${platformKey};
        };
        # Anthropic now serves this release's binary uncompressed; nixpkgs'
        # installPhase still assumes the old .zst-compressed distribution.
        installPhase =
          builtins.replaceStrings
            [ "unzstd -q $src -o $out/bin/claude" ]
            [
              "install -m755 $src $out/bin/claude"
            ]
            old.installPhase;
      }
    );
  })
]
