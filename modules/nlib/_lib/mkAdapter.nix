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
  libDefTypeModule = import ./libDefType.nix { inherit lib; };
  inherit (libDefTypeModule) flattenLibs unflattenFns;

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

  # Flatten nested lib definitions
  flatLibDefs = flattenLibs "" (cfg.lib or { });

  # Convert lib definitions to metadata format
  # Uses resolved functions from config.lib so overrides are tested
  libDefsToMeta =
    defs: resolvedFns:
    lib.mapAttrs (attrName: def: {
      name = attrName;
      # Use resolved function from config.lib, fallback to def.fn for private libs
      fn =
        let
          path = lib.splitString "." attrName;
          resolved = lib.attrByPath path null resolvedFns;
        in
        if resolved != null then resolved else def.fn;
      description = def.description or "";
      type = def.type or null;
      tests = lib.mapAttrs (_: t: {
        args = t.args or { };
        expected = t.expected or null;
        assertions = t.assertions or [ ];
      }) (def.tests or { });
    }) defs;

  # Extract plain functions (only visible/public ones)
  # Default visible to true if not specified
  extractFnsFlat =
    defs: lib.mapAttrs (_: def: def.fn) (lib.filterAttrs (_: def: def.visible or true) defs);

  # Get lib definitions, flatten, extract, unflatten
  allLibs = if cfg.enable then unflattenFns (extractFnsFlat flatLibDefs) else { };
  # Use config.lib for resolved functions (includes overrides)
  allMeta = if cfg.enable then libDefsToMeta flatLibDefs config.lib else { };
in
{
  imports = [ ../_all.nix ];

  # Define options.nlib.lib for lib definitions
  # Supports nested namespaces
  options.nlib.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    description = ''
      Lib definitions for ${name}. Supports nested namespaces.

      Usage:
      ```nix
      nlib.lib.myFunc = {
        type = lib.types.functionTo lib.types.int;
        fn = x: x * 2;
        description = "Double a number";
        tests."doubles 5" = { args.x = 5; expected = 10; };
      };

      # Nested namespace
      nlib.lib.utils.helper = {
        type = lib.types.functionTo lib.types.str;
        fn = x: "helper: " + x;
        description = "Helper function";
      };
      ```

      Functions are available at config.lib.<path>
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
