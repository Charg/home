{
  stdenv,
  lib,
  fetchzip,
  glib,
  gitUpdater,
}:
let
  uuid = "vicinae@dagimg-dot";
in
stdenv.mkDerivation rec {
  pname = "gnome-shell-extension-vicinae";
  version = "1.7.2";

  src = fetchzip {
    url = "https://github.com/vicinaehq/gnome-extension/releases/download/v${version}/vicinae%40dagimg-dot.shell-extension-v${version}.zip";
    hash = "sha256-vtjMjH7FXty4RDTTyhBSdVUqG+EPKUXsXuidSU4uIyg=";
    stripRoot = false;
  };

  nativeBuildInputs = [ glib ];

  installPhase = ''
    mkdir -p "$out/share/gnome-shell/extensions/${uuid}"
    cp -r * "$out/share/gnome-shell/extensions/${uuid}/"
    glib-compile-schemas "$out/share/gnome-shell/extensions/${uuid}/schemas"
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
    homepage = "https://github.com/vicinaehq/gnome-extension";
    changelog = "https://github.com/vicinaehq/gnome-extension/releases";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = lib.platforms.linux;
  };
}
