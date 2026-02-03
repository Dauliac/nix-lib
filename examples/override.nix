# Example: Private libs (visible = false)
#
# nix-lib uses the module system, so you can:
# - Mark functions as private with visible = false
# - Private functions are tested but not exported
#
{ lib, ... }:
{
  # ============================================================
  # Private function (visible = false)
  # ============================================================

  # Private: not exported to config.lib, but still tested
  nix-lib.lib._internal = {
    type = lib.types.functionTo lib.types.int;
    fn = x: x * x;
    description = "Internal helper - square a number";
    visible = false; # Won't appear in config.lib or flake.lib
    tests."squares 4" = {
      args.x = 4;
      expected = 16;
    };
  };

  # Public function that uses private helper logic
  nix-lib.lib.sumOfSquares = {
    type = lib.types.functionTo lib.types.int;
    fn =
      { a, b }:
      let
        square = x: x * x; # Inline since _internal isn't in config.lib
      in
      square a + square b;
    description = "Sum of squares of two numbers";
    tests."sum of 3 and 4 squared" = {
      args.x = {
        a = 3;
        b = 4;
      };
      expected = 25; # 9 + 16
    };
  };

  # ============================================================
  # Patterns summary
  # ============================================================
  #
  # Private (not exported, still tested):
  #   nix-lib.lib._helper = {
  #     visible = false;
  #     fn = ...;
  #   };
  #
  # Override (must be in a SEPARATE module):
  #   # base.nix
  #   nix-lib.lib.foo = { fn = x: defaultImpl; ... };
  #
  #   # override.nix (imported after base.nix)
  #   nix-lib.lib.foo.fn = lib.mkForce (x: newImpl);
}
