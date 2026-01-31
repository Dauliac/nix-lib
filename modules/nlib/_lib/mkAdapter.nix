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
# Functions are available at config.lib.<name>
#
# Nested module propagation:
#   When NixOS imports home-manager, home-manager libs are available at:
#     config.lib.home.<libname>
#   When home-manager imports nixvim, nixvim libs are available at:
#     config.lib.vim.<libname>
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
    system-manager = "system";
    flake = "lib";
  };

  # Define which nested systems each adapter should look for
  # Supports deep nesting: NixOS -> home-manager -> nixvim
  nestedSystems = {
    nixos = [
      {
        name = "home";
        path = [
          "home-manager"
          "users"
        ];
        multi = true; # Multiple users
      }
      {
        # nixvim nested inside home-manager users
        name = "vim";
        path = [
          "home-manager"
          "users"
        ];
        multi = true;
        # Deep path: go into each user, then programs.nixvim
        nestedPath = [
          "programs"
          "nixvim"
        ];
      }
    ];
    home-manager = [
      {
        name = "vim";
        path = [
          "programs"
          "nixvim"
        ];
        multi = false;
      }
    ];
    nix-darwin = [
      {
        name = "home";
        path = [
          "home-manager"
          "users"
        ];
        multi = true;
      }
      {
        # nixvim nested inside home-manager users
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
    system-manager = [
      # system-manager can have home-manager-like user configs
      # Add more nested systems here as needed
    ];
    nixvim = [
      # nixvim doesn't typically nest other module systems
    ];
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
  options,
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
      visible = def.visible or true;
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
  # Use config.nlib._fns for resolved functions (includes overrides)
  allMeta = if cfg.enable then libDefsToMeta flatLibDefs cfg._fns else { };

  # Extract libs from nested module systems
  # e.g., home-manager users in NixOS, nixvim in home-manager
  nestedSystemsForAdapter = nestedSystems.${name} or [ ];

  extractNestedLibs =
    let
      extractFromNested =
        nested:
        let
          # Check if the path exists in options (not config, to avoid infinite recursion)
          pathExists = lib.hasAttrByPath nested.path options;
          nestedConfig = lib.attrByPath nested.path { } config;
          # Support deep nesting: nestedPath goes inside each multi instance
          hasNestedPath = nested ? nestedPath && nested.nestedPath != [ ];
        in
        if !pathExists then
          { }
        else if nested.multi or false then
          # Multiple instances (e.g., home-manager.users.<name>)
          lib.foldl' (
            acc: instanceName:
            let
              instance = nestedConfig.${instanceName} or { };
              # If nestedPath is specified, go deeper (e.g., users.<name>.programs.nixvim)
              target =
                if hasNestedPath then lib.attrByPath nested.nestedPath { } instance else instance;
              libs = target.nlib._libs or { };
            in
            acc // libs
          ) { } (lib.attrNames nestedConfig)
        else
          # Single instance (e.g., programs.nixvim)
          let
            target =
              if hasNestedPath then lib.attrByPath nested.nestedPath { } nestedConfig else nestedConfig;
          in
          target.nlib._libs or { };

      # Collect libs from all nested systems, namespaced
      # Merge libs into existing namespace if it already exists
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

  # Merge own libs with nested libs
  nestedLibs = if cfg.enable then extractNestedLibs else { };
  mergedLibs = allLibs // nestedLibs;

  # Systems that have options.lib built-in (we just set config.lib, don't declare)
  # NixOS: nixos/modules/misc/lib.nix
  # home-manager: modules/lib/default.nix
  systemsWithBuiltinLib = [ "nixos" "home-manager" ];
  hasBuiltinLib = builtins.elem name systemsWithBuiltinLib;

in
{
  imports = [ ../_all.nix ];

  options = {
    # Define options.nlib.lib for lib definitions
    # Supports nested namespaces
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

    # Internal option for storing functions (used by tests and metadata)
    nlib._fns = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = { };
      internal = true;
      description = "Internal: Lib functions (auto-populated from nlib.lib)";
    };
  } // lib.optionalAttrs (!hasBuiltinLib) {
    # Declare options.lib for systems that don't have it built-in
    lib = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = { };
      description = "Lib functions merged from nlib";
    };
  };

  config = {
    # Store functions internally for metadata and tests
    nlib._fns = mergedLibs;

    # Merge libs directly into config.lib
    lib = mergedLibs;

    nlib.namespace = lib.mkDefault namespace;
    # Only export own libs (not nested) for collection at flake level
    nlib._libs = allLibs;
    nlib._libsMeta = allMeta;
  };
}
