# Example: using mkLibOptionFromFileName (name derived from filename)
#
# This file should be imported via wrapLibModule:
#   import-tree.map nlib.wrapLibModule ./perLib
{ lib, mkLibOptionFromFileName, ... }:
{
  options.lib = mkLibOptionFromFileName {
    # name is automatically "add" (from filename)
    type = lib.types.functionTo (lib.types.functionTo lib.types.int);
    fn = a: b: a + b;
    description = "Add two integers";
    tests = {
      "basic addition" = {
        args = {
          a = 2;
          b = 3;
        };
        expected = 5;
        fn = args: args.a + args.b;
      };
      "with zero" = {
        args = {
          a = 5;
          b = 0;
        };
        expected = 5;
        fn = args: args.a + args.b;
      };
      "negative numbers" = {
        args = {
          a = -3;
          b = 7;
        };
        expected = 4;
        fn = args: args.a + args.b;
      };
    };
  };
}
