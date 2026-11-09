{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}:

# Upstream's statically linked release build. Being static, `hc machine add`
# can copy this binary as-is to another machine with the same OS and CPU.
# To refresh: curl -fsSL https://releases.herdr.dev/core/latest.json
# and update `version`/`checksums` below to match.
let
  version = "0.1.19";
  checksums = {
    "x86_64-linux" = "4adcfb423d52f24c5cc4a1e2cd2fcad1f62d28bb77876ac472c29082a3eaa424";
    "aarch64-linux" = "f95c34fd7177ed58807d74fe4ee78bb3dc73eb37f21c69496064000a21abcb10";
  };
  inherit (stdenvNoCC.hostPlatform) system;
  target = "linux-${stdenvNoCC.hostPlatform.parsed.cpu.name}";
in
stdenvNoCC.mkDerivation {
  pname = "herdr-core";
  inherit version;

  src = fetchurl {
    url = "https://releases.herdr.dev/core/${version}/herdr-core-${target}.tar.gz";
    sha256 = checksums.${system};
  };

  sourceRoot = ".";

  # hc tells builds apart by their GNU build id; leave the binary untouched.
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 herdr-core -t $out/bin
    ln -s herdr-core $out/bin/hc
    install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-core
    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Persistent terminal and coding agent backend for Herdr";
    homepage = "https://github.com/herdrdev/herdr-core";
    license = with lib.licenses; [
      asl20
      mit
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames checksums;
    mainProgram = "hc";
  };
}
