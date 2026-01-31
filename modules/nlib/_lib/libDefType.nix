# libDefType - Option type for lib definitions with nested namespace support
#
# Supports both flat and nested definitions:
#   nlib.lib.double = { fn = ...; };           # flat
#   nlib.lib.treefmt.check = { fn = ...; };    # nested
#
{ lib }:
let
  inherit (lib)
    mkOption
    types
    ;

  # Test case submodule
  testCaseType = types.submodule {
    options = {
      args = mkOption {
        type = types.attrsOf types.unspecified;
        description = "Arguments to pass to the function";
      };
      expected = mkOption {
        type = types.unspecified;
        default = null;
        description = "Expected return value (for simple tests)";
      };
      assertions = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                default = "assertion";
                description = "Name of this assertion";
              };
              expected = mkOption {
                type = types.unspecified;
                default = null;
                description = "Expected value for this assertion";
              };
              check = mkOption {
                type = types.nullOr (types.functionTo types.bool);
                default = null;
                description = "Predicate function to check result";
              };
            };
          }
        );
        default = [ ];
        description = "Multiple assertions for this test case";
      };
      doc = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Documentation overrides for args/expected display";
      };
    };
  };

  # Lib definition submodule
  libDefType = types.submodule (
    { name, ... }:
    {
      options = {
        type = mkOption {
          type = types.unspecified;
          description = "The Nix type of this function (e.g., lib.types.functionTo lib.types.int)";
        };

        fn = mkOption {
          type = types.unspecified;
          description = "The function implementation";
        };

        description = mkOption {
          type = types.str;
          description = "Description of what this function does";
        };

        tests = mkOption {
          type = types.attrsOf testCaseType;
          default = { };
          description = "Test cases for this function";
        };

        example = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional example usage";
        };

        visible = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to show in documentation and export to config.lib";
        };

        # Internal: the name is inferred from the attribute name
        _name = mkOption {
          type = types.str;
          default = name;
          internal = true;
          description = "Internal: the lib name (inferred from attr name)";
        };
      };
    }
  );

  # Check if a value looks like a lib definition (has fn attribute)
  isLibDef = v: builtins.isAttrs v && v ? fn;

  # Flatten nested lib definitions to a flat attrset with dotted names
  # e.g., { treefmt.check = {...}; double = {...}; }
  #    -> { "treefmt.check" = {...}; double = {...}; }
  flattenLibs =
    prefix: attrs:
    lib.foldl' (
      acc: name:
      let
        value = attrs.${name};
        fullName = if prefix == "" then name else "${prefix}.${name}";
      in
      if isLibDef value then
        acc // { ${fullName} = value; }
      else if builtins.isAttrs value then
        acc // (flattenLibs fullName value)
      else
        acc
    ) { } (builtins.attrNames attrs);

  # Unflatten dotted names back to nested structure for config.lib output
  # e.g., { "treefmt.check" = fn; double = fn; }
  #    -> { treefmt.check = fn; double = fn; }
  unflattenFns =
    flatFns:
    lib.foldl' (
      acc: name:
      let
        value = flatFns.${name};
        path = lib.splitString "." name;
      in
      lib.recursiveUpdate acc (lib.setAttrByPath path value)
    ) { } (builtins.attrNames flatFns);
  # Extract nlib metadata from lib definition (supports both formats)
  # Legacy: { name, tests, fn, ... }
  # New: { _nlib = { name, tests, fn, ... }; ... }
  getMeta = def: def._nlib or def;

  # Convert lib definitions to metadata format for backends
  # Uses resolved functions from config.lib so overrides are tested
  libDefsToMeta =
    defs: resolvedFns:
    lib.mapAttrs (
      attrName: def: {
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
      }
    ) defs;

  # Extract plain functions from lib definitions (only visible/public ones)
  # Default visible to true if not specified
  extractFnsFlat =
    defs: lib.mapAttrs (_: def: def.fn) (lib.filterAttrs (_: def: def.visible or true) defs);
in
{
  inherit
    libDefType
    testCaseType
    isLibDef
    flattenLibs
    unflattenFns
    getMeta
    libDefsToMeta
    extractFnsFlat
    ;
}
