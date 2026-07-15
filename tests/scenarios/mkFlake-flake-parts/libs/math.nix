# math lib module
{ lib, config, ... }:
{
  lib.math.double = {
    fn = x: x * 2;
    description = "Double a number";
    tests."doubles 5" = {
      args.x = 5;
      expected = 10;
    };
  };

  # Self-referencing: quadruple uses double
  lib.math.quadruple = {
    fn = x: config.lib.math.double.fn (config.lib.math.double.fn x);
    description = "Quadruple a number using double";
    tests."quadruples 3" = {
      args.x = 3;
      expected = 12;
    };
  };
}
