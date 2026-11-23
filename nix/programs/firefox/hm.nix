{ lib, host, ... }:

let
  configPath = ".mozilla/firefox";

  amo = slug: "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
in
{
  programs.firefox = {
    enable = host.isLinux;
    inherit configPath;

    # Policies apply to every profile.
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFeedbackCommands = true;

      # Keep DNS on the LAN resolver; Firefox's DoH rollout would bypass it.
      DNSOverHTTPS = {
        Enabled = false;
        Locked = true;
      };

      EnableTrackingProtection = {
        Value = true;
        Cryptomining = true;
        Fingerprinting = true;
        EmailTracking = true;
      };

      FirefoxHome = {
        SponsoredTopSites = false;
        SponsoredPocket = false;
        Pocket = false;
      };
      FirefoxSuggest = {
        SponsoredSuggestions = false;
        ImproveSuggest = false;
      };
      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        MoreFromMozilla = false;
        SkipOnboarding = true;
      };

      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = amo "ublock-origin";
          installation_mode = "force_installed";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = amo "bitwarden-password-manager";
          installation_mode = "force_installed";
        };
      };
    };

    # Paths match the existing profile directories so data is kept.
    profiles = {
      default = {
        id = 0;
        isDefault = true;
        path = "0415mmm8.default";
        settings = {
          # Prefs come from Nix; Sync still handles bookmarks, tabs, add-ons.
          "services.sync.engine.prefs" = false;

          "browser.startup.page" = 3; # restore previous session
          "signon.rememberSignons" = false;

          "browser.contentblocking.category" = "strict";
          "privacy.globalprivacycontrol.enabled" = true;
          "dom.private-attribution.submission.enabled" = false;
          "dom.security.https_only_mode" = true;
          "browser.urlbar.suggest.quicksuggest.sponsored" = false;
          "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
          "browser.discovery.enabled" = false;
          "extensions.getAddons.showPane" = false;
          "network.prefetch-next" = false;
        };
      };

      # Left unmanaged: no user.js, prefs stay as set in the UI.
      CoStar = {
        id = 1;
        path = "efszpmw9.CoStar";
      };
    };
  };

  # Replace the profiles.ini Firefox created instead of failing on collision.
  home.file = lib.mkIf host.isLinux { "${configPath}/profiles.ini".force = true; };
}
