{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "agent-orchestrator";
  version = "0.12.6";

  src = fetchurl {
    url = "https://github.com/Untrivial-ai/agent-orchestrator/releases/download/v${version}/agent-orchestrator-linux-x64.AppImage";
    hash = "sha256-OXHHH0eqCEGzjTE7YGjkrIJ40ZXo1hW1RSRxTZCbRkQ=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/agent-orchestrator.desktop $out/share/applications/${pname}.desktop
    install -m 444 -D ${appimageContents}/agent-orchestrator.png $out/share/icons/hicolor/1024x1024/apps/${pname}.png
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=${pname} %U'
  '';

  meta = {
    description = "Agent IDE for managing fleets of coding agents";
    homepage = "https://github.com/Untrivial-ai/agent-orchestrator";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
