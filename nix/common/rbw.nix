{
  config,
  pkgs,
  host,
  ...
}:

# rbw config, rendered from this host's secrets/rbw.enc.yaml (keys: email,
# base-url). home-manager links ~/.config/rbw/config.json to the rendered
# file, so `rbw config set` can't edit it; change the sops file instead.
let
  ph = config.sops.placeholder;
  renderedPath = config.sops.templates."rbw-config.json".path;
in
{
  sops.secrets.rbw-email = {
    sopsFile = host.secretsFile "rbw";
    key = "email";
  };
  sops.secrets.rbw-base-url = {
    sopsFile = host.secretsFile "rbw";
    key = "base-url";
  };

  sops.templates."rbw-config.json" = {
    owner = host.user;
    content = builtins.toJSON {
      email = ph.rbw-email;
      base_url = ph.rbw-base-url;
      lock_timeout = 3600;
      sync_interval = 3600;
      pinentry = "${pkgs.pinentry-gnome3}/bin/pinentry-gnome3";
    };
  };

  home-manager.users.${host.user}.imports = [
    (hm: {
      xdg.configFile."rbw/config.json".source = hm.config.lib.file.mkOutOfStoreSymlink renderedPath;
    })
  ];
}
