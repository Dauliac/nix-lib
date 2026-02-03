# mkAdapter - Factory to create nix-lib adapters for any module system
#
# Usage:
#   imports = [ (nix-lib.mkAdapter { name = "nixos"; }) ];
#   imports = [ (nix-lib.mkAdapter { name = "home-manager"; }) ];
#   imports = [ (nix-lib.mkAdapter { name = "nixvim"; }) ];
#
# Or with explicit adapterDef:
#   imports = [ (nix-lib.mkAdapter {
#     name = "custom";
#     adapterDef = {
#       namespace = "custom";
#       hasBuiltinLib = false;
#       nestedSystems = [];
#     };
#   }) ];
#
# In NixOS/home-manager modules:
#   nix-lib.lib.myFunc = {
#     type = lib.types.functionTo lib.types.int;
#     fn = x: x * 2;
#     description = "Double a number";
#     tests."doubles 5" = { args.x = 5; expected = 10; };
#   };
#
# Functions are available at:
#   - config.nix-lib.fns.<name> (typed, overridable)
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
  cfg = config.nix-lib;

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
              # Get resolved functions from nested module's nix-lib.fns
              libs = target.nix-lib.fns or { };
            in
            acc // libs
          ) { } (lib.attrNames nestedConfig)
        else
          let
            target = if hasNestedPath then lib.attrByPath nested.nestedPath { } nestedConfig else nestedConfig;
          in
          target.nix-lib.fns or { };

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

  # Own libs from nix-lib.fns (resolved, after potential overrides)
  ownLibs = if cfg.enable then buildVisibleFnsStructure config.nix-lib.fns else { };

  # Merged libs for config.lib
  mergedLibs = ownLibs // nestedLibs;

  # Metadata for tests (uses resolved fns)
  allMeta = if cfg.enable then libDefsToMeta flatLibDefs config.nix-lib.fns else { };

in
{
  imports = [ ../_all.nix ];

  options = {
    # Define options.nix-lib.lib for lib definitions
    nix-lib.lib = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = { };
      description = ''
        Lib definitions for ${name}. Supports nested namespaces.

        Usage:
        ```nix
        nix-lib.lib.myFunc = {
          type = lib.types.functionTo lib.types.int;
          fn = x: x * 2;
          description = "Double a number";
          tests."doubles 5" = { args.x = 5; expected = 10; };
        };
        ```

        Functions are available at:
        - config.nix-lib.fns.myFunc (typed, overridable)
        - config.lib.myFunc (alias)
      '';
    };

    # Typed function options (generated from nix-lib.lib)
    nix-lib.fns = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = { };
      description = ''
        Typed function options generated from nix-lib.lib definitions.

        Override functions here with type checking:
          config.nix-lib.fns.double = x: x * 3;
      '';
    };

    # Internal: for backwards compatibility
    nix-lib._fns = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = { };
      internal = true;
      description = "Deprecated: Use nix-lib.fns instead";
    };

    # Internal: nested libs for collection
    nix-lib._nestedFns = lib.mkOption {
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
      description = "Lib functions merged from nix-lib";
    };
  };

  config = lib.mkIf cfg.enable {
    # Generate functions from lib definitions
    nix-lib.fns = generateFns flatLibDefs;

    # Backwards compatibility: _fns mirrors fns (own libs only)
    nix-lib._fns = config.nix-lib.fns;

    # Export nested libs separately for collection
    # These are libs from nested module systems (e.g., home-manager inside NixOS)
    nix-lib._nestedFns = nestedLibs;

    # Alias visible functions to config.lib (merged with nested)
    lib = mergedLibs;

    nix-lib.namespace = lib.mkDefault resolvedDef.namespace;

    # Export own libs for collection (visible only, flat)
    nix-lib._libs = extractFnsFlat flatLibDefs;
    nix-lib._libsMeta = allMeta;
  };
}
