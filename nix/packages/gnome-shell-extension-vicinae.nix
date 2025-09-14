{
  stdenv,
  lib,
  fetchFromGitHub,
  gitUpdater,
}:
let
  uuid = "vicinae@dagimg-dot";
in
stdenv.mkDerivation rec {
  pname = "gnome-shell-extension-vicinae";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "dagimg-dot";
    repo = "vicinae-gnome-extension";
    tag = "v${version}";
    hash = "sha256-Nimc9pRRrrJaqPdZWBYf4INJ3Qr46AQOoQtf4A317xg=";
  };

  installPhase = ''
    mkdir -p "$out/share/gnome-shell/extensions/${uuid}"
    cp -r * "$out/share/gnome-shell/extensions/${uuid}/"
  '';

  passthru = {
    extensionUuid = uuid;
    extensionPortalSlug = "vicinae";
    updateScript = gitUpdater {
      rev-prefix = "v";
    };
  };

  meta = {
    description = "GNOME Shell integration for Vicinae";
    homepage = "https://github.com/dagimg-dot/vicinae-gnome-extension";
    changelog = "https://github.com/dagimg-dot/vicinae-gnome-extension/releases";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = lib.platforms.linux;
  };
}
