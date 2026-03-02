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
  };
}
