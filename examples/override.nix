# Example: Overriding lib functions and private libs
#
# nlib uses the module system, so you can:
# - Override functions with lib.mkForce or module priorities
# - Mark functions as private with visible = false
#
# Tests run against config.lib.*, so overridden functions are tested.
#
{ lib, ... }:
{
  # ============================================================
  # Public function with override
  # ============================================================

  nlib.lib.greet = {
    type = lib.types.functionTo lib.types.str;
    fn = name: "Hello, ${name}!";
    description = "Greet someone";
    tests."greets Alice" = {
      args.name = "Alice";
      expected = "Bonjour, Alice!"; # Test expects the OVERRIDDEN result
    };
  };

  # Override the function - tests will run against this version
  nlib.lib.greet.fn = lib.mkForce (name: "Bonjour, ${name}!");

  # ============================================================
  # Private function (visible = false)
  # ============================================================

  # Private: not exported to config.lib.*, but still tested
  nlib.lib._internal = {
    type = lib.types.functionTo lib.types.int;
    fn = x: x * x;
    description = "Internal helper - square a number";
    visible = false; # Won't appear in config.lib.flake
    tests."squares 4" = {
      args.x = 4;
      expected = 16;
    };
  };

  # Private functions can be used by other libs in the same module
  nlib.lib.sumOfSquares = {
    type = lib.types.functionTo (lib.types.functionTo lib.types.int);
    fn =
      a: b:
      let
        square = x: x * x; # Inline since _internal isn't in config.lib
      in
      square a + square b;
    description = "Sum of squares of two numbers";
    tests."sum of 3 and 4 squared" = {
      args = {
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
  # Override:
  #   nlib.lib.foo.fn = lib.mkForce (x: newImpl);
  #
  # Private (not exported, still tested):
  #   nlib.lib._helper = {
  #     visible = false;
  #     fn = ...;
  #   };
  #
  # Default (can be overridden by consumers):
  #   nlib.lib.foo.fn = lib.mkDefault (x: defaultImpl);
}
