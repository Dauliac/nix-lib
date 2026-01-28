# Example: Defining libs in flake-parts (pure, no pkgs dependency)
#
# These are available at: flake.lib.<name>
#
# Usage in flake.nix:
#   imports = [ nlib.flakeModules.default ];
#   lib.flake.double = { ... };
#
{ lib, ... }:
{
  # Pure flake-level lib - no system/pkgs dependency
  lib.flake.double = {
    type = lib.types.functionTo lib.types.int;
    fn = x: x * 2;
    description = "Double a number";
    tests."doubles 5" = {
      args.x = 5;
      expected = 10;
    };
    tests."doubles negative" = {
      args.x = -3;
      expected = -6;
    };
  };

  lib.flake.add = {
    type = lib.types.functionTo (lib.types.functionTo lib.types.int);
    fn = a: b: a + b;
    description = "Add two integers";
    tests."adds positives" = {
      args = { a = 2; b = 3; };
      expected = 5;
    };
  };

  lib.flake.compose = {
    type = lib.types.functionTo (lib.types.functionTo (lib.types.functionTo lib.types.unspecified));
    fn = f: g: x: f (g x);
    description = "Compose two functions (f . g)";
    tests."composes double and add1" = {
      args = {
        f = x: x * 2;
        g = x: x + 1;
        x = 5;
      };
      expected = 12; # (5 + 1) * 2
    };
  };
}
