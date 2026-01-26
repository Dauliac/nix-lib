# nlib module options
{ lib, ... }:
let
  inherit (lib) mkOption types;

  # deferredModule type for perLib (allows merging multiple module contributions)
  deferredModuleWith =
    { staticModules ? [ ] }:
    types.mkOptionType {
      name = "deferredModule";
      description = "module";
      check = x: builtins.isAttrs x || builtins.isFunction x || lib.isPath x;
      merge =
        loc: defs:
        staticModules ++ map (def: lib.setDefaultModuleLocation "nlib.perLib" def.value) defs;
    };
in
{
  options.nlib = {
    namespace = mkOption {
      type = types.str;
      default = "lib";
      description = "Namespace under flake.lib where functions are exposed";
      example = "myproject";
    };

    # New: perLib for dendritic pattern
    perLib = mkOption {
      type = deferredModuleWith { };
      default = [ ];
      description = ''
        Per-lib module configuration. Modules contribute to options.lib which merge together.

        Usage:
        ```nix
        nlib.perLib = { lib, mkLibOption, ... }: {
          options.lib = mkLibOption {
            name = "add";
            type = lib.types.functionTo (lib.types.functionTo lib.types.int);
            fn = a: b: a + b;
            description = "Add two integers";
            tests = { "basic" = { args = { a = 2; b = 3; }; expected = 5; }; };
          };
        };
        ```

        With import-tree:
        ```nix
        nlib.perLib = import-tree.map nlib.wrapLibModule ./libs;
        ```
      '';
    };

    # Legacy: direct libs definition
    libs = mkOption {
      type = types.lazyAttrsOf types.unspecified;
      default = { };
      description = "Library functions created with mkLib (legacy, use perLib instead)";
    };

    testing = {
      backend = mkOption {
        type = types.enum [
          "nix-unit"
          "nixt"
          "nixtest"
          "runTests"
        ];
        default = "nix-unit";
        description = "Test framework backend to use";
      };
    };

    coverage = {
      threshold = mkOption {
        type = types.ints.between 0 100;
        default = 100;
        description = "Minimum test coverage percentage required (0 = disabled)";
      };
    };
  };
}
