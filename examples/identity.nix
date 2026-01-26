# Example: identity function
{ lib, mkLib }:

mkLib {
  name = "identity";
  type = lib.types.functionTo lib.types.int;
  fn = x: x;
  description = "Return the input unchanged";
  tests = {
    "returns input" = {
      args = {
        x = 42;
      };
      expected = 42;
    };
    "handles zero" = {
      args = {
        x = 0;
      };
      expected = 0;
    };
  };
}
