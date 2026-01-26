# Example: using mkLibOption with explicit name
{ lib, mkLibOption, ... }:
{
  options.lib = mkLibOption {
    name = "multiply"; # explicit name
    type = lib.types.functionTo (lib.types.functionTo lib.types.int);
    fn = a: b: a * b;
    description = "Multiply two integers";
    tests = {
      "basic multiplication" = {
        args = {
          a = 3;
          b = 4;
        };
        expected = 12;
        fn = args: args.a * args.b;
      };
      "with zero" = {
        args = {
          a = 5;
          b = 0;
        };
        expected = 0;
        fn = args: args.a * args.b;
      };
    };
  };
}
