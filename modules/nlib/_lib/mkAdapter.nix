# mkAdapter - Factory to create nlib adapters for any module system
#
# Usage:
#   imports = [ (nlib.mkAdapter { name = "nixos"; }) ];
#   imports = [ (nlib.mkAdapter { name = "home-manager"; }) ];
#   imports = [ (nlib.mkAdapter { name = "nixvim"; }) ];
#
# In NixOS/home-manager modules:
#   nlib.lib.myFunc = {
#     type = lib.types.functionTo lib.types.int;
#     fn = x: x * 2;
#     description = "Double a number";
#     tests."doubles 5" = { args.x = 5; expected = 10; };
#   };
#
# The plain functions are auto-populated to config.lib.<name>
#
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

  # Extract plain functions (only visible/public ones)
  extractFns = defs: lib.mapAttrs (_: def: def.fn) (lib.filterAttrs (_: def: def.visible) defs);

  # Get lib definitions from nlib.lib
  libDefs = cfg.lib or { };
  allMeta = if cfg.enable then libDefsToMeta libDefs else { };
  allLibs = if cfg.enable then extractFns libDefs else { };
in
{
  imports = [ ../_all.nix ];

  # Define options.nlib.lib for lib definitions
  options.nlib.lib = lib.mkOption {
    type = lib.types.attrsOf libDefType;
    default = { };
    description = ''
      Lib definitions for ${name}.

      Usage:
      ```nix
      nlib.lib.myFunc = {
        type = lib.types.functionTo lib.types.int;
        fn = x: x * 2;
        description = "Double a number";
        tests."doubles 5" = { args.x = 5; expected = 10; };
      };
      ```

      The plain functions are auto-populated to config.lib.<name>
    '';
  };

  # Define options.lib for the extracted functions (output)
  options.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    description = "Lib functions (auto-populated from nlib.lib)";
  };

  config = {
    # Auto-populate lib with extracted functions
    lib = allLibs;

    nlib.namespace = lib.mkDefault namespace;
    nlib._libs = allLibs;
    nlib._libsMeta = allMeta;
  };
}
