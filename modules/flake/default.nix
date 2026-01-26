# nlib flake.parts module
#
# Provides:
#   - flake.lib.{namespace}: Library functions
#   - flake.lib.nlib: mkLibOption helpers
#   - flake.tests.{namespace}: Tests in selected backend format
{ lib, ... }:
let
  nlibLib = import ../../lib { inherit lib; };
in
{
  imports = [ ./options.nix ];

  config =
    { config, ... }:
    let
      cfg = config.nlib;

      # Evaluate perLib modules to get lib options
      evaluatedPerLib =
        if cfg.perLib == [ ] then
          { config.lib = { }; }
        else
          lib.evalModules {
            modules = cfg.perLib;
            specialArgs = {
              inherit lib;
              inherit (nlibLib) mkLibOption;
              # Note: mkLibOptionFromFileName requires path context from wrapLibModule
            };
          };

      # Merge libs from perLib evaluation and legacy libs option
      perLibDefs = evaluatedPerLib.config.lib or { };
      allLibs = cfg.libs // perLibDefs;

      # Extract functions (handle both legacy and new format)
      getMeta = def: def._nlib or def;
      libFns = lib.mapAttrs (_: d: (getMeta d).fn or d.fn or d) allLibs;

      # Transform tests to selected backend format
      tests = nlibLib.backends.toBackend cfg.testing.backend allLibs;

      # Calculate coverage
      coverage = nlibLib.coverage.calculate allLibs;
    in
    {
      # Expose library functions
      flake.lib.${cfg.namespace} = libFns;

      # Expose nlib helpers for consumers
      flake.lib.nlib = {
        inherit (nlibLib) mkLibOption mkLibOptionFromFileName wrapLibModule;
        # Legacy
        inherit (nlibLib) mkLib mkLibFromFile;
      };

      # Expose tests in backend format
      flake.tests.${cfg.namespace} = tests;

      # Coverage enforcement
      assertions = lib.optional (cfg.coverage.threshold > 0) {
        assertion = coverage.percent >= cfg.coverage.threshold;
        message = "nlib: test coverage ${toString coverage.percent}% is below threshold ${toString cfg.coverage.threshold}%";
      };
    };

  # Per-system configuration for checks
  perSystem =
    {
      pkgs,
      inputs',
      config,
      ...
    }:
    let
      cfg = config.nlib or { };
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
