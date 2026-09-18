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
        version = "2.1.277";
        baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
        checksums = {
          "darwin-arm64" = "73d6a2a55c46907e49bd8bb7608e134333bd71173351ee16ddce7d7db9914b9c";
          "darwin-x64" = "82b74d616e360cdff37dd1cecdf03e6bdfaa02411d914faac7af22a273a3132d";
          "linux-arm64" = "242c4d743beabc822edd8f247101bb800b4036c69e74b9e2a1adb120dfe46f5d";
          "linux-x64" = "722210f05ba494d8f6df69423c4d4f2960900f7a007d0532851c7a36e375cab7";
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
