# math lib module
{ lib, ... }:
{
  lib.math.double = {
    fn = x: x * 2;
    description = "Double a number";
    tests."doubles 5" = {
      args.x = 5;
      expected = 10;
    };
    tests."doubles 0" = {
      args.x = 0;
      expected = 0;
    };
  };

  lib.math.triple = {
    fn = x: x * 3;
    description = "Triple a number";
    tests."triples 3" = {
      args.x = 3;
      expected = 9;
    };
  };
}
