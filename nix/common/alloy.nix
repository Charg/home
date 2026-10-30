{ config, currentSystemName, ... }:

let
  hostName = config.networking.hostName;
  # Per-host credential for the nuc01 ingest endpoints. systemd hands the
  # decrypted file to the (DynamicUser) service under this fixed path.
  credentialPath = "/run/credentials/alloy.service/telemetry-password";
in
{
  sops.secrets.telemetry-password = {
    sopsFile = ../machines/${currentSystemName}/secrets/telemetry.enc.yaml;
    restartUnits = [ "alloy.service" ];
  };

  systemd.services.alloy.serviceConfig.LoadCredential = [
    "telemetry-password:${config.sops.secrets.telemetry-password.path}"
  ];

  services.alloy = {
    enable = true;
    extraFlags = [ "--disable-reporting" ];
  };

  # SMART health/wear for all disks, autodiscovered. Scraped by the Alloy
  # config below; listens on localhost only.
  services.prometheus.exporters.smartctl = {
    enable = true;
    listenAddress = "127.0.0.1";
  };

  environment.etc."alloy/config.alloy".text = ''
    prometheus.exporter.unix "host" {
      enable_collectors = ["systemd"]
    }

    // Match the in-cluster node-exporter job so the bundled Node Exporter
    // dashboards and recording rules pick this host up.
    discovery.relabel "host" {
      targets = prometheus.exporter.unix.host.targets

      rule {
        target_label = "job"
        replacement  = "node-exporter"
      }
      rule {
        target_label = "instance"
        replacement  = "${hostName}"
      }
    }

    prometheus.scrape "host" {
      targets         = discovery.relabel.host.output
      scrape_interval = "30s"
      forward_to      = [prometheus.remote_write.nuc01.receiver]
    }

    prometheus.scrape "smartctl" {
      targets = [{
        __address__ = "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}",
        job         = "smartctl",
        instance    = "${hostName}",
      }]
      scrape_interval = "60s"
      forward_to      = [prometheus.remote_write.nuc01.receiver]
    }

    prometheus.remote_write "nuc01" {
      endpoint {
        url = "https://prometheus.home.packet.fail/api/v1/write"
        basic_auth {
          username      = "${hostName}"
          password_file = "${credentialPath}"
        }
      }
    }

    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }
    }

    loki.source.journal "host" {
      max_age       = "12h"
      relabel_rules = loki.relabel.journal.rules
      labels        = { host = "${hostName}", job = "systemd-journal" }
      forward_to    = [loki.process.journal.receiver]
    }

    // NixOS lists each dbus package both as an explicit <servicedir> and via
    // XDG_DATA_DIRS, so dbus-broker logs ~100 "Ignoring duplicate name" lines
    // at error priority on every reload. Harmless; drop them.
    loki.process "journal" {
      stage.drop {
        expression          = "^Ignoring duplicate name '.*' in service file"
        drop_counter_reason = "dbus_duplicate_name"
      }
      forward_to = [loki.write.nuc01.receiver]
    }

    loki.write "nuc01" {
      endpoint {
        url = "https://loki.home.packet.fail/loki/api/v1/push"
        basic_auth {
          username      = "${hostName}"
          password_file = "${credentialPath}"
        }
      }
    }
  '';
}
