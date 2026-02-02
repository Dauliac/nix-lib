# mkAdapter - Factory to create nlib adapters for any module system
#
# Usage:
#   imports = [ (nlib.mkAdapter { name = "nixos"; }) ];
#   imports = [ (nlib.mkAdapter { name = "home-manager"; }) ];
#   imports = [ (nlib.mkAdapter { name = "nixvim"; }) ];
#
# Or with explicit adapterDef:
#   imports = [ (nlib.mkAdapter {
#     name = "custom";
#     adapterDef = {
#       namespace = "custom";
#       hasBuiltinLib = false;
#       nestedSystems = [];
#     };
#   }) ];
#
# In NixOS/home-manager modules:
#   nlib.lib.myFunc = {
#     type = lib.types.functionTo lib.types.int;
#     fn = x: x * 2;
#     description = "Double a number";
#     tests."doubles 5" = { args.x = 5; expected = 10; };
#   };
#
# Functions are available at:
#   - config.nlib.fns.<name> (typed, overridable)
#   - config.lib.<name> (alias, visible only)
#
{ lib }:
let
  libDefTypeModule = import ./libDefType.nix { inherit lib; };
  inherit (libDefTypeModule) flattenLibs libDefsToMeta extractFnsFlat;

  # Default adapter definitions (fallback when not passed explicitly)
  defaultAdapterDefs = {
    nixos = {
      namespace = "nixos";
      hasBuiltinLib = true;
      nestedSystems = [
        {
          name = "home";
          path = [
            "home-manager"
            "users"
          ];
          multi = true;
        }
        {
          name = "vim";
          path = [
            "home-manager"
            "users"
          ];
          multi = true;
          nestedPath = [
            "programs"
            "nixvim"
          ];
        }
      ];
    };
    home-manager = {
      namespace = "home";
      hasBuiltinLib = true;
      nestedSystems = [
        {
          name = "vim";
          path = [
            "programs"
            "nixvim"
          ];
          multi = false;
        }
      ];
    };
    nix-darwin = {
      namespace = "darwin";
      hasBuiltinLib = false;
      nestedSystems = [
        {
          name = "home";
          path = [
            "home-manager"
            "users"
          ];
          multi = true;
        }
        {
          name = "vim";
          path = [
            "home-manager"
            "users"
          ];
          multi = true;
          nestedPath = [
            "programs"
            "nixvim"
          ];
        }
      ];
    };
    nixvim = {
      namespace = "vim";
      hasBuiltinLib = false;
      nestedSystems = [ ];
    };
    system-manager = {
      namespace = "system";
      hasBuiltinLib = false;
      nestedSystems = [ ];
    };
    wrappers = {
      namespace = "wrappers";
      hasBuiltinLib = false;
      nestedSystems = [ ];
    };
  };
in
{
  name,
  namespace ? null,
  adapterDef ? defaultAdapterDefs.${name} or { },
}:
let
  # Resolve adapter configuration
  resolvedDef = {
    namespace = if namespace != null then namespace else (adapterDef.namespace or name);
    hasBuiltinLib = adapterDef.hasBuiltinLib or false;
    nestedSystems = adapterDef.nestedSystems or [ ];
  };
in
# Return a NixOS-style module
{
  config,
  lib,
  options,
  ...
}:
let
  cfg = config.nlib;

  # Flatten nested lib definitions
  flatLibDefs = flattenLibs "" (cfg.lib or { });

  # Extract functions from lib definitions (nested structure)
  # For now, type checking happens at definition time via the type attribute
  # Future: could add runtime type checking wrapper
  generateFns =
    defs:
    lib.foldl' (
      acc: attrName:
      let
        def = defs.${attrName};
        path = lib.splitString "." attrName;
      in
      lib.recursiveUpdate acc (lib.setAttrByPath path def.fn)
    ) { } (builtins.attrNames defs);

  # Extract visible functions for config.lib alias
  visibleFns = lib.filterAttrs (_: def: def.visible or true) flatLibDefs;

  # Build nested structure from flat visible fns
  buildVisibleFnsStructure =
    fnsConfig:
    lib.foldl' (
      acc: attrName:
      let
        path = lib.splitString "." attrName;
        value = lib.attrByPath path null fnsConfig;
      in
      if value != null then lib.recursiveUpdate acc (lib.setAttrByPath path value) else acc
    ) { } (builtins.attrNames visibleFns);

  # Extract libs from nested module systems
  nestedSystemsForAdapter = resolvedDef.nestedSystems;

  extractNestedLibs =
    let
      extractFromNested =
        nested:
        let
          pathExists = lib.hasAttrByPath nested.path options;
          nestedConfig = lib.attrByPath nested.path { } config;
          hasNestedPath = nested ? nestedPath && nested.nestedPath != [ ];
        in
        if !pathExists then
          { }
        else if nested.multi or false then
          lib.foldl' (
            acc: instanceName:
            let
              instance = nestedConfig.${instanceName} or { };
              target = if hasNestedPath then lib.attrByPath nested.nestedPath { } instance else instance;
              # Get resolved functions from nested module's nlib.fns
              libs = target.nlib.fns or { };
            in
            acc // libs
          ) { } (lib.attrNames nestedConfig)
        else
          let
            target = if hasNestedPath then lib.attrByPath nested.nestedPath { } nestedConfig else nestedConfig;
          in
          target.nlib.fns or { };

      # Collect libs from all nested systems, namespaced
      collectedNested = lib.foldl' (
        acc: nested:
        let
          libs = extractFromNested nested;
          existing = acc.${nested.name} or { };
        in
        if libs == { } then acc else acc // { ${nested.name} = existing // libs; }
      ) { } nestedSystemsForAdapter;
    in
    collectedNested;

  # Nested libs
  nestedLibs = if cfg.enable then extractNestedLibs else { };

  # Own libs from nlib.fns (resolved, after potential overrides)
  ownLibs = if cfg.enable then buildVisibleFnsStructure config.nlib.fns else { };

  # Merged libs for config.lib
  mergedLibs = ownLibs // nestedLibs;

  # Metadata for tests (uses resolved fns)
  allMeta = if cfg.enable then libDefsToMeta flatLibDefs config.nlib.fns else { };

in
{
  imports = [ ../_all.nix ];

  options = {
    # Define options.nlib.lib for lib definitions
    nlib.lib = lib.mkOption {
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
        ```

        Functions are available at:
        - config.nlib.fns.myFunc (typed, overridable)
        - config.lib.myFunc (alias)
      '';
    };

    # Typed function options (generated from nlib.lib)
    nlib.fns = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = { };
      description = ''
        Typed function options generated from nlib.lib definitions.

        Override functions here with type checking:
          config.nlib.fns.double = x: x * 3;
      '';
    };

    # Internal: for backwards compatibility
    nlib._fns = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = { };
      internal = true;
      description = "Deprecated: Use nlib.fns instead";
    };

    # Internal: nested libs for collection
    nlib._nestedFns = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = { };
      internal = true;
      description = "Nested module libs for collector aggregation";
    };
  }
  // lib.optionalAttrs (!resolvedDef.hasBuiltinLib) {
    # Declare options.lib for systems that don't have it built-in
    lib = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = { };
      description = "Lib functions merged from nlib";
    };
  };

  config = lib.mkIf cfg.enable {
    # Generate functions from lib definitions
    nlib.fns = generateFns flatLibDefs;

    # Backwards compatibility: _fns mirrors fns (own libs only)
    nlib._fns = config.nlib.fns;

    # Export nested libs separately for collection
    # These are libs from nested module systems (e.g., home-manager inside NixOS)
    nlib._nestedFns = nestedLibs;

    # Alias visible functions to config.lib (merged with nested)
    lib = mergedLibs;

    nlib.namespace = lib.mkDefault resolvedDef.namespace;

    # Export own libs for collection (visible only, flat)
    nlib._libs = extractFnsFlat flatLibDefs;
    nlib._libsMeta = allMeta;
  };
}
