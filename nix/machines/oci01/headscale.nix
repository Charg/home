{ unstable-pkgs, ... }:

let
  domain = "headscale.packet.fail";
in
{
  services.headscale = {
    enable = true;
    # nixos-26.05 lags upstream releases
    package = unstable-pkgs.headscale;
    address = "0.0.0.0";
    port = 443;

    settings = {
      server_url = "https://${domain}";

      # The REST API (/api/v1) is served on this public listener with no way
      # to split it off; only API keys gate it. Keep zero keys, and mint
      # short-lived ones only when needed. Bind any admin UI to localhost or
      # the tailnet. The CLI uses the unix socket and doesn't need gRPC.
      grpc_listen_addr = "127.0.0.1:50443";

      # Built-in ACME. TLS-ALPN-01 validates on :443 itself, so nothing
      # listens on :80
      tls_letsencrypt_hostname = domain;
      tls_letsencrypt_challenge_type = "TLS-ALPN-01";

      # MagicDNS suffix; must not be the same as, or a parent of, the server domain
      dns = {
        magic_dns = true;
        base_domain = "ts.packet.fail";
        # Clients keep their own resolver; only the MagicDNS suffix goes
        # through tailscale, and the global nameservers become fallbacks
        override_local_dns = false;
        nameservers.global = [
          "1.1.1.1"
          "1.0.0.1"
        ];
      };

      # Embedded DERP relay alongside Tailscale's public ones
      derp.server = {
        enabled = true;
        region_id = 999;
        region_code = "oci";
        region_name = "Oracle Cloud";
        stun_listen_addr = "0.0.0.0:3478";
        automatically_add_embedded_derp_region = true;
      };

      # Without a policy headscale allows all traffic between nodes
      policy = {
        mode = "file";
        # Copy just this file; a plain ./policy.hujson resolves inside the whole
        # flake source and drags the entire repo onto the box
        path = builtins.path {
          path = ./policy.hujson;
          name = "headscale-policy.hujson";
        };
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 443 ];
    allowedUDPPorts = [ 3478 ];
  };
}
