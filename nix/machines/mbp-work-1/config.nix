{ ... }:

{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "none";
      upgrade = true;
    };
    brews = [
      "awscli"
      "jfrog-cli"
    ];
    caskArgs = {
      appdir = "~/Applications";
      require_sha = true;
    };
    casks = [
      "amethyst"
      "elgato-wave-link"
      "firefox"
      "flameshot"
      "ghostty"
      "google-chrome"
      # herdr-core on macOS is installed by the app as a signed bundle
      # (stable privacy grants), so it isn't nix-packaged here.
      "herdr-app"
      "intellij-idea-ce"
      "podman-desktop"
      "raycast"
      "slack"
      "vagrant"
      "virtualbox"
      {
        name = "zulu@21";
        args = {
          require_sha = false;
        };
      }
      "zoom"
    ];
    taps = [
      "deskflow/homebrew-tap"
    ];
  };
}
