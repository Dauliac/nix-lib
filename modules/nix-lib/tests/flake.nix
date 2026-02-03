# flake.tests (flake-level)
#
# Generates test cases from lib metadata for nix-unit.
#
{ lib, config, ... }:
let
  nixLibLib = import ../_lib { inherit lib; };
  cfg = config.nix-lib;

  # Get flake-level lib metadata
  flakeLibsMeta = cfg._flakeLibsMeta or { };

  # Get collected metadata from all module systems
  collectedMeta = lib.mapAttrs (_: collector: collector config) (cfg.metaCollectors or { });

  # Flatten all collected metadata
  allMetaFlat =
    flakeLibsMeta // lib.foldl' (acc: meta: acc // meta) { } (lib.attrValues collectedMeta);

  # Generate tests using the configured backend
  tests = nixLibLib.backends.toBackend cfg.testing.backend allMetaFlat;
in
{
  # Tests go directly under flake.tests (nix-unit expects this structure)
  config.flake.tests = tests;
}
