# nix-lib flake.parts module
#
# Provides nix-lib.lib.<name> API for defining libs:
#
#   nix-lib.lib.double = {
#     type = lib.types.functionTo lib.types.int;
#     fn = x: x * 2;
#     description = "Double a number";
#     tests."doubles 5" = { args.x = 5; expected = 10; };
#   };
#
# Output structure:
#   - flake.lib.flake.<name> for pure flake libs (no pkgs dependency)
#   - flake.lib.nix-lib for internal utilities
#   - legacyPackages.<sys>.lib.<ns>.<name> for module system libs (system-specific)
#
{ lib, config, ... }:
let
  nixLibLib = import ../_lib { inherit lib; };
  libDefTypeModule = import ../_lib/libDefType.nix { inherit lib; };
  inherit (libDefTypeModule)
    flattenLibs
    unflattenFns
    libDefsToMeta
    extractFnsFlat
    ;
  cfg = config.nix-lib;

  # Flatten nested lib definitions (nix-lib.lib.treefmt.check -> "treefmt.check")
  flatLibDefs = flattenLibs "" (cfg.lib or { });

  # Flake-level libs - flatten, extract, then unflatten for nested output
  flakeLibsFlatFns = extractFnsFlat flatLibDefs;
  flakeLibs = unflattenFns flakeLibsFlatFns;
  # Use config.lib.flake for resolved functions (includes overrides)
  flakeLibsMeta = libDefsToMeta flatLibDefs config.lib.flake;

  # Collection config for collectors
  collectorConfig = config // {
    systems = config.systems or [ ];
  };

  # Flat collection for flake.lib output (merges all systems)
  # Uses legacy flat collectors for backwards compatibility
  collectedLibsByNamespace = lib.mapAttrs (_: collector: collector collectorConfig) (
    cfg.collectors or { }
  );

  # System-aware collection for legacyPackages output
  # Returns: { namespace -> { system -> { name -> fn } } }
  collectedByNamespaceBySystem = lib.mapAttrs (_: collector: collector collectorConfig) (
    cfg.systemCollectors or { }
  );

  # Collected metadata for tests (uses metaCollectors which get _libsMeta)
  collectedMeta = lib.mapAttrs (_: collector: collector collectorConfig) (cfg.metaCollectors or { });

  # For tests, flatten all metadata
  allMetaFlat =
    flakeLibsMeta // lib.foldl' (acc: meta: acc // meta) { } (lib.attrValues collectedMeta);

  tests = nixLibLib.backends.toBackend cfg.testing.backend allMetaFlat;
in
{
  imports = [
    ./perSystem.nix
    ./systemLibs.nix
    # Note: adapterDefs is imported by import-tree at the nix-lib level
  ];

  # Define options.nix-lib.lib for flake-level lib definitions
  # Supports nested namespaces: nix-lib.lib.treefmt.check = {...}
  options.nix-lib.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    description = ''
      Pure flake-level lib definitions (no pkgs dependency).
      Supports nested namespaces.

      Usage:
      ```nix
      # Flat
      nix-lib.lib.double = {
        type = lib.types.functionTo lib.types.int;
        fn = x: x * 2;
        description = "Double a number";
        tests."doubles 5" = { args.x = 5; expected = 10; };
      };

      # Nested namespace
      nix-lib.lib.treefmt.check = {
        type = lib.types.functionTo lib.types.bool;
        fn = x: x == "formatted";
        description = "Check if formatted";
        tests."is formatted" = { args.x = "formatted"; expected = true; };
      };
      ```

      Functions are available at lib.flake.<path> (e.g., lib.flake.treefmt.check)
    '';
  };

  # Define options.lib.flake for the extracted functions (output)
  options.lib.flake = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    description = "Pure flake-level lib functions (auto-populated from nix-lib.lib)";
  };

  # Store system-aware collection for perSystem module to access
  options.nix-lib._collectedBySystem = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    internal = true;
    description = "System-aware collected libs for legacyPackages export";
  };

  # Note: flake.tests option is declared by nix-unit module
  # (nix-unit.modules.flake.default or via nix-lib's nix-unit.nix import)

  config = {
    # Auto-populate lib.flake with extracted functions
    lib.flake = flakeLibs;

    # flake.lib exports:
    # - flake.lib.flake.<name> for pure flake libs
    # - flake.lib.nix-lib for internal utilities
    # - flake.lib.<namespace>.<name> for collected libs (from collectorDefs)
    # Also available at legacyPackages.<sys>.lib.<ns> for system-specific access
    flake.lib = {
      inherit (config.lib) flake;
      nix-lib = nixLibLib;
    }
    // collectedLibsByNamespace;

    # Tests go directly under flake.tests (nix-unit expects this structure)
    flake.tests = tests;

    # Store metadata for test collection
    nix-lib._flakeLibsMeta = flakeLibsMeta;

    # Store system-aware collection for systemLibs.nix to use
    nix-lib._collectedBySystem = collectedByNamespaceBySystem;
  };
}
