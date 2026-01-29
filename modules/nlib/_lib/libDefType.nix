# libDefType - Option type for lib definitions
#
# Usage:
#   options.lib = lib.mkOption {
#     type = lib.types.attrsOf libDefType;
#   };
#
#   config.lib.double = {
#     type = lib.types.functionTo lib.types.int;
#     fn = x: x * 2;
#     description = "Double the input";
#     tests."doubles 5" = { args.x = 5; expected = 10; };
#   };
{ lib }:
let
  inherit (lib)
    mkOption
    types
    ;

  # Check if test uses assertions format

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
          description = "Whether to show in documentation";
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
in
libDefType
