# nlib.testing options
{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.nlib;
in
{
  options.nlib.testing.backend = mkOption {
    type = types.enum [
      "nix-unit"
      "nixt"
      "nixtest"
      "runTests"
    ];
    default = "nix-unit";
    description = "Test framework backend to use";
  };

  # Per-system checks for nix-unit
  config.perSystem =
    { pkgs, inputs', config, ... }:
    let
      backend = cfg.testing.backend or "nix-unit";
    in
    {
      checks = lib.optionalAttrs (backend == "nix-unit" && (cfg.libs or { }) != { }) {
        nlib-tests = pkgs.runCommand "nlib-tests" { } ''
          ${inputs'.nix-unit.packages.default}/bin/nix-unit --flake .#tests
          touch $out
        '';
      };
    };
}
