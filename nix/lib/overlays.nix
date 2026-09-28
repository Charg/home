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
        version = "2.1.284";
        baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
        checksums = {
          "darwin-arm64" = "50a14c2f50f56668380fdda490167f1d3630d5cc18fb8aed3073c2c7ea7314fe";
          "darwin-x64" = "79441b868935a11ed0630b2ee59327eda9f6a93bb8d470bd6633c03df76d2135";
          "linux-arm64" = "3dd0f96d7ada463152d20300186f6cfc6ab94b57e218f49e3ac86db42ac695a6";
          "linux-x64" = "5cd90aabd83f8a15136c35aa37bb1d92b348993573316643dc3fe4e04afbf88f";
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
