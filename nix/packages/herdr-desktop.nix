{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  libxcb,
  libxkbcommon,
  libGL,
  vulkan-loader,
  wayland,
  versionCheckHook,
}:

# Upstream's release build of the Herdr desktop app (`herdr-app`).
# To refresh: curl -fsSL https://releases.herdr.dev/app/latest.json
# and update `version`/`checksums` below to match.
let
  version = "0.1.14";
  checksums = {
    "x86_64-linux" = "475a383f8f439e3191a86635b5c1286ce4dfd2d9fcdf1e7cbdfdd6c7176f8ff3";
    "aarch64-linux" = "30a431ce95c17356efe8afed50c4eaf8888d83ef45acd9aa911094d51707d007";
  };
  inherit (stdenv.hostPlatform) system;
  target = "linux-${stdenv.hostPlatform.parsed.cpu.name}";
in
stdenv.mkDerivation {
  pname = "herdr-desktop";
  inherit version;

  src = fetchurl {
    url = "https://releases.herdr.dev/app/${version}/herdr-app-${target}.tar.gz";
    sha256 = checksums.${system};
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libxcb
    libxkbcommon
  ];

  # wgpu (Vulkan, with OpenGL as fallback) and the Wayland backend dlopen
  # these. They go on the RUNPATH rather than in a wrapper's LD_LIBRARY_PATH:
  # the app starts herdr-core, which passes its environment to every terminal.
  runtimeDependencies = [
    libGL
    vulkan-loader
    wayland
  ];

  # The icon is kept out of bin/ on purpose: the app's self-updater only runs
  # when it finds herdr-app.svg beside its own binary.
  installPhase = ''
    runHook preInstall
    install -Dm755 herdr-app -t $out/bin
    install -Dm644 herdr-app.svg $out/share/icons/hicolor/scalable/apps/herdr-app.svg
    install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-desktop
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "herdr-app";
      desktopName = "Herdr";
      comment = "Terminals and coding agents that keep running";
      exec = "herdr-app";
      icon = "herdr-app";
      terminal = false;
      categories = [ "Development" ];
      startupWMClass = "herdr-app";
    })
  ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Desktop app for persistent terminals and coding agents";
    homepage = "https://github.com/herdrdev/herdr-app";
    license = with lib.licenses; [
      asl20
      ofl
      mit
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames checksums;
    mainProgram = "herdr-app";
  };
}
