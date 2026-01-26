# Example: add function
{ lib, mkLib }:

mkLib {
  name = "add";
  type = lib.types.functionTo (lib.types.functionTo lib.types.int);
  fn = a: b: a + b;
  description = "Add two integers";
  tests = {
    "basic addition" = {
      args = {
        a = 1;
        b = 2;
      };
      expected = 3;
    };
    "handles zero" = {
      args = {
        a = 0;
        b = 5;
      };
      expected = 5;
    };
    "negative numbers" = {
      args = {
        a = -1;
        b = 1;
      };
      expected = 0;
    };
  };
}
