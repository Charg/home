{ config, ... }:

let
  hostName = config.networking.hostName;
in
{
  services.alloy = {
    enable = true;
    extraFlags = [ "--disable-reporting" ];
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

    prometheus.remote_write "nuc01" {
      endpoint {
        url = "https://prometheus.home.packet.fail/api/v1/write"
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
      forward_to    = [loki.write.nuc01.receiver]
    }

    loki.write "nuc01" {
      endpoint {
        url = "https://loki.home.packet.fail/loki/api/v1/push"
      }
    }
  '';
}
