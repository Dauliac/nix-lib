# Example: function with hyphenated name (tests sanitization)
{ lib, mkLib }:

mkLib {
  name = "my-function";
  type = lib.types.functionTo lib.types.int;
  fn = x: x * 2;
  description = "Double the input";
  tests = {
    "test case" = {
      args = {
        x = 5;
      };
      expected = 10;
    };
  };
}
