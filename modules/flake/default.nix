# nlib flake.parts module
#
# Provides:
#   - flake.lib.{namespace}: Library functions
#   - flake.lib.nlib: mkLibOption helpers
#   - flake.tests.{namespace}: Tests in selected backend format
{ lib, ... }:
let
  nlibLib = import ../lib { inherit lib; };
in
{
  imports = [
    ./namespace.nix
    ./perLib.nix
    ./testing.nix
    ./coverage.nix
  ];

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
            };
          };

      # Get libs from perLib evaluation
      allLibs = evaluatedPerLib.config.lib or { };

      # Extract functions
      getMeta = def: def._nlib or def;
      libFns = lib.mapAttrs (_: d: (getMeta d).fn or d.fn or d) allLibs;

      # Transform tests to selected backend format
      tests = nlibLib.backends.toBackend cfg.testing.backend allLibs;

      # Calculate coverage
      coverageResult = nlibLib.coverage.calculate allLibs;
    in
    {
      # Expose library functions
      flake.lib.${cfg.namespace} = libFns;

      # Expose nlib helpers for consumers
      flake.lib.nlib = {
        inherit (nlibLib) mkLibOption mkLibOptionFromFileName wrapLibModule;
      };

      # Expose tests in backend format
      flake.tests.${cfg.namespace} = tests;

      # Coverage enforcement
      assertions = lib.optional (cfg.coverage.threshold > 0) {
        assertion = coverageResult.percent >= cfg.coverage.threshold;
        message = "nlib: test coverage ${toString coverageResult.percent}% is below threshold ${toString cfg.coverage.threshold}%";
      };
    };
}
