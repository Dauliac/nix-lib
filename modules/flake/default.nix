# nlib flake.parts module
#
# Provides:
#   - flake.lib.{namespace}: Library functions
#   - flake.lib.nlib: mkLib helper
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
      allLibs = cfg.libs;

      # Extract just the functions
      libFns = lib.mapAttrs (_: d: d.fn) allLibs;

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
        inherit (nlibLib) mkLib;
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
