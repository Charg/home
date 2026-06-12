{ config, pkgs, ... }:

let
  composeDir = "${config.home.homeDirectory}/.config/litellm";
in

{
  #
  # Secrets
  #
  # The encrypted dotenv file is decrypted at login by sops-nix.service and
  # symlinked to $HOME/.config/sops-nix/secrets/litellm-env.
  # It is referenced directly by the compose stack via env_file.
  #
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets.litellm-env = {
      sopsFile = ../../machines/framework/secrets/litellm.env.enc;
      format = "binary";
    };
  };

  #
  # Compose project
  #
  home.file.".config/litellm/docker-compose.yaml".source = ./docker-compose.yaml;

  #
  # Systemd user service
  #
  systemd.user.services.litellm-compose = {
    Unit = {
      Description = "LiteLLM + Postgres compose stack";
      After = [
        "sops-nix.service"
        "network-online.target"
      ];
      Wants = [
        "sops-nix.service"
        "network-online.target"
      ];
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = composeDir;
      ExecStart = "${pkgs.docker}/bin/docker compose up -d --remove-orphans";
      ExecStop = "${pkgs.docker}/bin/docker compose down";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
