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
  libDefTypeModule = import ../_lib/libDefType.nix { inherit lib; };
  inherit (libDefTypeModule) flattenLibs unflattenFns;
  cfg = config.nlib;

  # Flatten nested lib definitions (nlib.lib.treefmt.check -> "treefmt.check")
  flatLibDefs = flattenLibs "" (cfg.lib or { });

  # Convert lib definitions to metadata format for backends
  # Uses resolved functions from config.lib so overrides are tested
  libDefsToMeta =
    defs: resolvedFns:
    lib.mapAttrs (name: def: {
      inherit name;
      # Use resolved function from config.lib, fallback to def.fn for private libs
      # For nested names like "treefmt.check", traverse the resolved structure
      fn =
        let
          path = lib.splitString "." name;
          resolved = lib.attrByPath path null resolvedFns;
        in
        if resolved != null then resolved else def.fn;
      description = def.description or "";
      type = def.type or null;
      visible = def.visible or true;
      tests = lib.mapAttrs (_: t: {
        args = t.args or { };
        expected = t.expected or null;
        assertions = t.assertions or [ ];
      }) (def.tests or { });
    }) defs;

  # Extract plain functions from lib definitions (only visible/public ones)
  # Returns flat attrset with dotted names
  # Default visible to true if not specified
  extractFnsFlat =
    defs: lib.mapAttrs (_: def: def.fn) (lib.filterAttrs (_: def: def.visible or true) defs);

  # Flake-level libs - flatten, extract, then unflatten for nested output
  flakeLibsFlatFns = extractFnsFlat flatLibDefs;
  flakeLibs = unflattenFns flakeLibsFlatFns;
  # Use config.lib.flake for resolved functions (includes overrides)
  flakeLibsMeta = libDefsToMeta flatLibDefs config.lib.flake;

  # Collected libs from other module systems (nixos, home, etc.)
  collectedMeta = lib.mapAttrs (_: collector: collector config) (cfg.metaCollectors or { });
  # Extract fns from collected metadata (only visible/public ones)
  # Then unflatten to get proper nested structure (e.g., "vim.mkKeymap" -> { vim.mkKeymap = fn; })
  extractCollectedFns =
    meta:
    let
      flatFns = lib.mapAttrs (_: m: m.fn) (lib.filterAttrs (_: m: m.visible or true) meta);
    in
    unflattenFns flatFns;
  collectedLibsByNamespace = lib.mapAttrs (_: extractCollectedFns) collectedMeta;

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
  # Supports nested namespaces: nlib.lib.treefmt.check = {...}
  options.nlib.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    description = ''
      Pure flake-level lib definitions (no pkgs dependency).
      Supports nested namespaces.

      Usage:
      ```nix
      # Flat
      nlib.lib.double = {
        type = lib.types.functionTo lib.types.int;
        fn = x: x * 2;
        description = "Double a number";
        tests."doubles 5" = { args.x = 5; expected = 10; };
      };

      # Nested namespace
      nlib.lib.treefmt.check = {
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
      system = collectedLibsByNamespace.system or { };
    }
    // collectedLibsByNamespace;

    flake.tests.${cfg.namespace} = tests;

    # Store metadata for test collection
    nlib._flakeLibsMeta = flakeLibsMeta;
  };
}
