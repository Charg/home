# Evaluate-only package inventory for every host, used by the flake-lock-diff
# workflow. Nothing is built: it reads the name/version of each package a host
# installs (system packages, home-manager packages, kernel).
#
#   nix eval --impure --json --expr \
#     'import ./.github/scripts/flake-packages.nix { flake = builtins.getFlake "/path/to/repo"; }'
#
# Output: { "<host>": { "<pname>": "<version>[, <version>...]" } }
{ flake }:
let
  lib = flake.inputs.nixpkgs.lib;

  # Packages that fail to evaluate (broken/insecure/unsupported) are skipped
  # rather than failing the whole inventory.
  info =
    p:
    let
      r = builtins.tryEval (
        let
          parsed = builtins.parseDrvName (p.name or "");
          name = p.pname or parsed.name;
          version = p.version or parsed.version;
        in
        builtins.deepSeq [
          name
          version
        ] { inherit name version; }
      );
    in
    if r.success && r.value.name != "" then [ r.value ] else [ ];

  inventory =
    cfg:
    let
      c = cfg.config;
      hmPackages = lib.concatMap (u: u.home.packages or [ ]) (
        builtins.attrValues (c.home-manager.users or { })
      );
      kernel = lib.optional (c ? boot.kernelPackages.kernel) c.boot.kernelPackages.kernel;
      all = lib.concatMap info (c.environment.systemPackages ++ hmPackages ++ kernel);
      grouped = lib.groupBy (x: x.name) all;
    in
    lib.mapAttrs (
      _: xs: lib.concatStringsSep ", " (lib.unique (lib.sort lib.lessThan (map (x: x.version) xs)))
    ) grouped;

  hosts =
    builtins.removeAttrs (flake.nixosConfigurations or { }) [ "iso" ]
    // (flake.darwinConfigurations or { });
in
lib.mapAttrs (_: inventory) hosts
