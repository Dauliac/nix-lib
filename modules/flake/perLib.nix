# nlib.perLib option - dendritic pattern for lib definitions
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
  options.nlib.perLib = mkOption {
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
}
