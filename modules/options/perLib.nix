# nlib.perLib
{ lib, ... }:
let
  deferredModuleWith =
    { staticModules ? [ ] }:
    lib.types.mkOptionType {
      name = "deferredModule";
      description = "module";
      check = x: builtins.isAttrs x || builtins.isFunction x || lib.isPath x;
      merge =
        loc: defs:
        staticModules ++ map (def: lib.setDefaultModuleLocation "nlib.perLib" def.value) defs;
    };
in
{
  options.nlib.perLib = lib.mkOption {
    type = deferredModuleWith { };
    default = [ ];
    description = ''
      Per-lib module configuration. Modules contribute to options.lib which merge together.

      Usage:
      ```nix
      nlib.perLib = { lib, mkLibOption, ... }: {
        options.lib = mkLibOption {
          name = "myFunc";
          type = lib.types.functionTo lib.types.int;
          fn = x: x * 2;
          description = "Double the input";
          tests = { "works" = { args = { x = 5; }; expected = 10; }; };
        };
      };
      ```
    '';
  };
}
