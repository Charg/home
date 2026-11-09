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

  # nixpkgs builds Herdr from source and trails upstream's releases; pin
  # upstream's release builds instead. Version bumps live in the package files.
  (final: prev: {
    herdr-core = final.callPackage ../packages/herdr-core.nix { };
    herdr-desktop = final.callPackage ../packages/herdr-desktop.nix { };
  })

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
        version = "2.1.319";
        baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
        checksums = {
          "darwin-arm64" = "1f53587e92dee8e089fa349188a4cda64fa34ace6e7b0ca2ee278ddaa3cc2ebd";
          "darwin-x64" = "af6f1f5510ae98d56a155bf8f007aa9d5b44efccc9c10c8e10ef35039e95a940";
          "linux-arm64" = "a7e687fd1cb054d651c7588223de3786c99d4c682365e3c3ae1e59ce7f3a591f";
          "linux-x64" = "dabafec82ca1319fa43d8be36a10fc61b1d11821cb98ad5df04ad95e199b8eed";
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
        #
        # nixpkgs also wraps the binary with `--prefix LD_LIBRARY_PATH` so voice
        # mode can dlopen libasound. Every process Claude spawns (Bash tool, MCP
        # servers) inherits that, and its alsa-lib can need a newer glibc than
        # the rest of the system, breaking e.g. Playwright's Chromium. Drop the
        # wrapper line and put alsa-lib on the binary's search path instead.
        #
        # It has to be DT_RPATH, not the DT_RUNPATH autoPatchelf writes: the
        # libasound user is the embedded audio-capture.node addon, which links
        # it directly, and glibc only consults the executable's DT_RPATH (never
        # its DT_RUNPATH) when resolving a dlopened library's dependencies.
        #
        # Patch by hand with patchelf >= 0.18 and --no-sort instead of using
        # autoPatchelf: growing .dynstr any other way relocates the Bun
        # standalone sections and the binary segfaults on start.
        installPhase = final.lib.pipe old.installPhase [
          (builtins.replaceStrings
            [ "unzstd -q $src -o $out/bin/claude" ]
            [
              "install -m755 $src $out/bin/claude"
            ]
          )
          (final.lib.splitString "\n")
          (builtins.filter (line: !(final.lib.hasInfix "LD_LIBRARY_PATH" line)))
          (final.lib.concatStringsSep "\n")
        ];
        dontAutoPatchelf = true;
        nativeBuildInputs =
          old.nativeBuildInputs
          ++ final.lib.optionals final.stdenv.hostPlatform.isLinux [ final.patchelfUnstable ];
        postFixup =
          (old.postFixup or "")
          + final.lib.optionalString final.stdenv.hostPlatform.isLinux ''
            patchelf --no-sort \
              --set-interpreter ${final.stdenv.cc.bintools.dynamicLinker} \
              --force-rpath --set-rpath ${final.lib.makeLibraryPath [ final.alsa-lib ]} \
              $out/bin/.claude-wrapped
          '';
      }
    );
  })
]
