# Example: Defining libs in flake-parts (pure, no pkgs dependency)
#
# Define at: nlib.lib.<name>
# Use at: config.lib.flake.<name> (within flake-parts)
# Output at: flake.lib.flake.<name>
#
# Usage in flake.nix:
#   imports = [ nlib.flakeModules.default ];
#   nlib.lib.double = { ... };
#
{ lib, ... }:
{
  # Pure flake-level lib - no system/pkgs dependency
  nlib.lib.double = {
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

  nlib.lib.add = {
    type = lib.types.functionTo lib.types.int;
    fn = { a, b }: a + b;
    description = "Add two integers";
    tests."adds positives" = {
      args.x = {
        a = 2;
        b = 3;
      };
      expected = 5;
    };
  };

  nlib.lib.compose = {
    type = lib.types.functionTo lib.types.unspecified;
    fn =
      {
        f,
        g,
        x,
      }:
      f (g x);
    description = "Compose two functions (f . g)";
    tests."composes double and add1" = {
      args.x = {
        f = x: x * 2;
        g = x: x + 1;
        x = 5;
      };
      expected = 12; # (5 + 1) * 2
    };
  };

  # ============================================================
  # Usage examples - access via config.lib.flake.<name>
  # ============================================================
  #
  # Within flake-parts modules:
  #   doubled = config.lib.flake.double 5;                      # => 10
  #   sum = config.lib.flake.add { a = 2; b = 3; };             # => 5
  #   result = config.lib.flake.compose {
  #     f = x: x * 2;
  #     g = x: x + 1;
  #     x = 5;
  #   };                                                         # => 12
  #
  # From flake outputs (e.g., in another flake):
  #   doubled = nlib.lib.flake.double 5;                         # => 10
  #   sum = nlib.lib.flake.add { a = 2; b = 3; };                # => 5
}
