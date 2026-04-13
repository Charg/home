{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.file = {
    ".local/bin/gen-yaml-patch" = {
      source = ./gen_yaml_patch.py;
      executable = true;
    };
    ".local/bin/decode-saml" = {
      source = ./decode-saml.py;
      executable = true;
    };
  };
}
