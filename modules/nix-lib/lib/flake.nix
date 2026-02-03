# nix-lib.lib (flake-level)
#
# Flake-level lib definitions (pure, no pkgs dependency).
#
# Usage:
#   nix-lib.lib.double = {
#     type = lib.types.functionTo lib.types.int;
#     fn = x: x * 2;
#     description = "Double a number";
#     tests."doubles 5" = { args.x = 5; expected = 10; };
#   };
#
# Output: lib.flake.<name>, flake.lib.flake.<name>
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
in
{
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

    # Store metadata for test collection
    nix-lib._flakeLibsMeta = flakeLibsMeta;

    # Store system-aware collection for legacyPackages to use
    nix-lib._collectedBySystem = collectedByNamespaceBySystem;
  };
}
