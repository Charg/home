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
        version = "2.1.281";
        baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
        checksums = {
          "darwin-arm64" = "a922981f6f3b55a251ef9f9dbaa0621a5f99cbcb5ca67f8a797476ccfc83f626";
          "darwin-x64" = "a9355cbb0d291ce948efcf61a6ef397401672f64fa5e5e67bca092fed6cd9088";
          "linux-arm64" = "dd27b36438a4fed1670cd29bad2fda6a73b628b6da55443e5c2f647fe6ed328f";
          "linux-x64" = "56fe3da88458465fb27d7e9299dddb3fead55750fb9c2de795f233b5eea6dce1";
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
