# mkAdapter - Factory to create nlib adapters for any module system
#
# Usage:
#   imports = [ (nlib.mkAdapter { name = "nixos"; }) ];
#   imports = [ (nlib.mkAdapter { name = "home-manager"; }) ];
#   imports = [ (nlib.mkAdapter { name = "nixvim"; }) ];
#
# In NixOS/home-manager modules:
#   config.lib.myFunc = {
#     type = lib.types.functionTo lib.types.int;
#     fn = x: x * 2;
#     description = "Double a number";
#     tests."doubles 5" = { args.x = 5; expected = 10; };
#   };
{ lib }:
let
  libDefType = import ./libDefType.nix { inherit lib; };

  namespaces = {
    nixos = "nixos";
    home-manager = "home";
    nixvim = "vim";
    nix-darwin = "darwin";
    flake = "lib";
  };
in
{
  name,
  namespace ? namespaces.${name} or name,
}:
# Return a NixOS-style module
{
  config,
  lib,
  ...
}:
let
  cfg = config.nlib;

  # Convert lib definitions to metadata format
  libDefsToMeta =
    defs:
    lib.mapAttrs (attrName: def: {
      name = attrName;
      inherit (def) fn description type;
      tests = lib.mapAttrs (_: t: {
        inherit (t) args;
        inherit (t) expected;
        inherit (t) assertions;
      }) def.tests;
    }) defs;

  # Extract plain functions
  extractFns = defs: lib.mapAttrs (_: def: def.fn) defs;

  # Get lib definitions from config.lib
  libDefs = config.lib or { };
  allMeta = if cfg.enable then libDefsToMeta libDefs else { };
  allLibs = if cfg.enable then extractFns libDefs else { };
in
{
  imports = [ ../_all.nix ];

  # Define options.lib for this module system
  options.lib = lib.mkOption {
    type = lib.types.attrsOf libDefType;
    default = { };
    description = ''
      Lib definitions for ${name}.

      Usage:
      ```nix
      config.lib.myFunc = {
        type = lib.types.functionTo lib.types.int;
        fn = x: x * 2;
        description = "Double a number";
        tests."doubles 5" = { args.x = 5; expected = 10; };
      };
      ```
    '';
  };

  config = {
    nlib.namespace = lib.mkDefault namespace;
    nlib._libs = allLibs;
    nlib._libsMeta = allMeta;
  };
}
