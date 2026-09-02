{ inputs }:

let
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
        version = "2.1.258";
        baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
        checksums = {
          "darwin-arm64" = "b63136194160791c27cfa7b0403060d85eb0752991625fde8c09f9acacb17c78";
          "darwin-x64" = "c857db5cd712865623bd61e806cf3f7e8e279c9e5c7c0af5eca06ca6717fc7fb";
          "linux-arm64" = "43dc490af55262edcb3e9b1cb315de22cc09ccb08bd52a4c39bc5eabaa63100f";
          "linux-x64" = "704f1334ac65d3e89e1c6c1d7663293ad786a6166afdb71b5075337df630f976";
        };
        platformKey = "${final.stdenv.hostPlatform.node.platform}-${final.stdenv.hostPlatform.node.arch}";
      in
      {
        inherit version;
        src = final.fetchurl {
          url = "${baseUrl}/${version}/${platformKey}/claude";
          sha256 = checksums.${platformKey};
        };
      }
    );
  })

  (unstableOverlay "herdr")
  (unstableOverlay "mise")
  (unstableOverlay "opencode")
  (unstableOverlay "prek")
]
