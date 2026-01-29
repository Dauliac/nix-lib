# nlib flake.parts module
#
# Provides direct config.lib.<class>.<name> API for defining libs:
#
#   config.lib.flake.double = {
#     type = lib.types.functionTo lib.types.int;
#     fn = x: x * 2;
#     description = "Double a number";
#     tests."doubles 5" = { args.x = 5; expected = 10; };
#   };
#
{ lib, config, ... }:
let
  nlibLib = import ../_lib { inherit lib; };
  libDefType = import ../_lib/libDefType.nix { inherit lib; };
  cfg = config.nlib;

  # Convert lib definitions to metadata format for backends
  libDefsToMeta =
    defs:
    lib.mapAttrs (name: def: {
      inherit name;
      inherit (def) fn description type;
      tests = lib.mapAttrs (_: t: {
        inherit (t) args;
        inherit (t) expected;
        inherit (t) assertions;
      }) def.tests;
    }) defs;

  # Extract plain functions from lib definitions
  extractFns = defs: lib.mapAttrs (_: def: def.fn) defs;

  # Flake-level libs
  flakeLibDefs = config.lib.flake or { };
  flakeLibsMeta = libDefsToMeta flakeLibDefs;
  flakeLibs = extractFns flakeLibDefs;

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
    # nlib option modules are auto-discovered by import-tree
    ./perSystem.nix
  ];

  # Define options.lib.<class> for each dendritic class
  options.lib = {
    flake = lib.mkOption {
      type = lib.types.attrsOf libDefType;
      default = { };
      description = ''
        Pure flake-level lib definitions (no pkgs dependency).

        Usage:
        ```nix
        config.lib.flake.double = {
          type = lib.types.functionTo lib.types.int;
          fn = x: x * 2;
          description = "Double a number";
          tests."doubles 5" = { args.x = 5; expected = 10; };
        };
        ```
      '';
    };

    nixos = lib.mkOption {
      type = lib.types.attrsOf libDefType;
      default = { };
      description = "NixOS-related lib definitions (collected from nixosConfigurations)";
    };

    home = lib.mkOption {
      type = lib.types.attrsOf libDefType;
      default = { };
      description = "Home-manager-related lib definitions";
    };

    darwin = lib.mkOption {
      type = lib.types.attrsOf libDefType;
      default = { };
      description = "Nix-darwin-related lib definitions";
    };

    vim = lib.mkOption {
      type = lib.types.attrsOf libDefType;
      default = { };
      description = "Nixvim-related lib definitions";
    };
  };

  config = {
    # flake.lib exports:
    # - flake.lib.<name> for pure flake libs
    # - flake.lib.nixos.<name> for nixos libs
    # - flake.lib.home.<name> for home-manager libs
    flake.lib =
      flakeLibs
      // {
        nlib = nlibLib;
        nixos = extractFns (config.lib.nixos or { });
        home = extractFns (config.lib.home or { });
        darwin = extractFns (config.lib.darwin or { });
        vim = extractFns (config.lib.vim or { });
      }
      // collectedLibsByNamespace;

    flake.tests.${cfg.namespace} = tests;

    # Store metadata for test collection
    nlib._flakeLibsMeta = flakeLibsMeta;
  };
}
