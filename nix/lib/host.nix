# The `host` special argument every module receives: what machine it is
# configuring. Same shape for NixOS, darwin, embedded and standalone Home
# Manager. Built from a flake host-table entry.
name:
{
  system,
  user,
  wsl ? false,
  ...
}:
let
  isDarwin = builtins.match ".*-darwin" system != null;
in
{
  # Flake attribute name; not necessarily networking.hostName.
  inherit
    name
    system
    user
    isDarwin
    ;
  isWSL = wsl;
  # Native Linux: false on darwin and on WSL.
  isLinux = !isDarwin && !wsl;

  # This host's sops file nix/machines/<name>/secrets/<secret>.enc.yaml;
  # a missing file is an evaluation error.
  secretsFile =
    secret:
    let
      file = ../machines/${name}/secrets/${secret}.enc.yaml;
    in
    if builtins.pathExists file then
      file
    else
      throw "host ${name} has no secrets file nix/machines/${name}/secrets/${secret}.enc.yaml";
}
