# `nix flake check` checks for one system. Evaluation checks cover the outputs
# flake check does not know about; they force every configuration's top-level
# derivation without building it, so they only run on x86_64-linux.
{ self, pkgs }:
let
  inherit (pkgs) lib;
  src = self.outPath;

  evalCheck =
    name: drvs:
    pkgs.writeText name (
      builtins.unsafeDiscardStringContext (builtins.toJSON (lib.mapAttrs (_: d: d.drvPath) drvs))
    );
in
{
  formatting = pkgs.runCommandLocal "formatting" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
    cd ${src}
    find . -name '*.nix' -print0 | xargs -0 nixfmt --check
    touch $out
  '';

  lint =
    pkgs.runCommandLocal "lint"
      {
        nativeBuildInputs = [
          pkgs.statix
          pkgs.deadnix
        ];
      }
      ''
        cd ${src}
        statix check .
        deadnix --fail --no-lambda-arg --no-lambda-pattern-names .
        touch $out
      '';
}
// lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  home-configurations = evalCheck "home-configurations" (
    lib.mapAttrs (_: c: c.activationPackage) self.homeConfigurations
  );

  darwin-configurations = evalCheck "darwin-configurations" (
    lib.mapAttrs (_: c: c.config.system.build.toplevel) self.darwinConfigurations
  );

  colmena-hive = evalCheck "colmena-hive" self.colmenaHive.toplevel;
}
