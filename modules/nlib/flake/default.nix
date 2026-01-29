# nlib flake.parts module
#
# Provides nlib.lib.<name> API for defining libs:
#
#   nlib.lib.double = {
#     type = lib.types.functionTo lib.types.int;
#     fn = x: x * 2;
#     description = "Double a number";
#     tests."doubles 5" = { args.x = 5; expected = 10; };
#   };
#
# The plain functions are auto-populated to lib.flake.<name>
#
{ lib, config, ... }:
let
  nlibLib = import ../_lib { inherit lib; };
  libDefType = import ../_lib/libDefType.nix { inherit lib; };
  cfg = config.nlib;

  # Convert lib definitions to metadata format for backends
  # Uses resolved functions from config.lib so overrides are tested
  libDefsToMeta =
    defs: resolvedFns:
    lib.mapAttrs (name: def: {
      inherit name;
      # Use resolved function from config.lib, fallback to def.fn for private libs
      fn = resolvedFns.${name} or def.fn;
      inherit (def) description type;
      tests = lib.mapAttrs (_: t: {
        inherit (t) args;
        inherit (t) expected;
        inherit (t) assertions;
      }) def.tests;
    }) defs;

  # Extract plain functions from lib definitions (only visible/public ones)
  extractFns = defs: lib.mapAttrs (_: def: def.fn) (lib.filterAttrs (_: def: def.visible) defs);

  # Flake-level libs from nlib.lib
  flakeLibDefs = cfg.lib or { };
  flakeLibs = extractFns flakeLibDefs;
  # Use config.lib.flake for resolved functions (includes overrides)
  flakeLibsMeta = libDefsToMeta flakeLibDefs config.lib.flake;

  # Collected libs from other module systems (nixos, home, etc.)
  collectedMeta = lib.mapAttrs (_: collector: collector config) (cfg.metaCollectors or { });
  collectedLibsByNamespace = lib.mapAttrs (_: extractFns) (
    lib.mapAttrs (_: meta: lib.mapAttrs (_: m: { inherit (m) fn; }) meta) collectedMeta
  );

  # For tests, flatten all metadata
  allMetaFlat =
    flakeLibsMeta // lib.foldl' (acc: meta: acc // meta) { } (lib.attrValues collectedMeta);

  tests = nlibLib.backends.toBackend cfg.testing.backend allMetaFlat;
in
{
  imports = [
    ./perSystem.nix
  ];

  # Define options.nlib.lib for flake-level lib definitions
  options.nlib.lib = lib.mkOption {
    type = lib.types.attrsOf libDefType;
    default = { };
    description = ''
      Pure flake-level lib definitions (no pkgs dependency).

      Usage:
      ```nix
      nlib.lib.double = {
        type = lib.types.functionTo lib.types.int;
        fn = x: x * 2;
        description = "Double a number";
        tests."doubles 5" = { args.x = 5; expected = 10; };
      };
      ```

      The plain functions are auto-populated to lib.flake.<name>
    '';
  };

  # Define options.lib.flake for the extracted functions (output)
  options.lib.flake = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    description = "Pure flake-level lib functions (auto-populated from nlib.lib)";
  };

  config = {
    # Auto-populate lib.flake with extracted functions
    lib.flake = flakeLibs;

    # flake.lib exports:
    # - flake.lib.flake.<name> for pure flake libs
    # - flake.lib.nixos.<name> for nixos libs
    # - flake.lib.home.<name> for home-manager libs
    flake.lib = {
      inherit (config.lib) flake;
      nlib = nlibLib;
      nixos = collectedLibsByNamespace.nixos or { };
      home = collectedLibsByNamespace.home or { };
      darwin = collectedLibsByNamespace.darwin or { };
      vim = collectedLibsByNamespace.vim or { };
    }
    // collectedLibsByNamespace;

    flake.tests.${cfg.namespace} = tests;

    # Store metadata for test collection
    nlib._flakeLibsMeta = flakeLibsMeta;
  };
}
