# Lib definition tests - BDD style flake-parts module
#
# Tests check structure, not specific functions (resilient to example changes)
# Tests are pure and don't depend on flake module evaluation in sandbox
#
# Note: These tests use flake.tests instead of perSystem.nix-unit.tests because
# the tests flake doesn't import nix-unit module (sandbox incompatibility with get-flake)
{ lib, config, ... }:
let
  flakeLib = config.flake.lib;

  hasNonEmpty = attr: set: lib.hasAttr attr set && (set.${attr} or { }) != { };
  hasFunction = set: lib.any lib.isFunction (lib.attrValues set);

  # Pre-evaluate all expressions at flake eval time
  results = {
    mkAdapterIsFunc = lib.isFunction (flakeLib.nlib.mkAdapter or null);
    backendsNonEmpty = hasNonEmpty "backends" (flakeLib.nlib or { });
    flakeHasFunc = hasFunction (flakeLib.flake or { });
  };
in
{
  # Note: nix-unit requires test names to start with "test"
  flake.tests = {
    "test_libDef_nlib_mkAdapter_is_function" = {
      expr = results.mkAdapterIsFunc;
      expected = true;
    };
    "test_libDef_nlib_backends_not_empty" = {
      expr = results.backendsNonEmpty;
      expected = true;
    };
    "test_libDef_flake_has_functions" = {
      expr = results.flakeHasFunc;
      expected = true;
    };
  };
}
