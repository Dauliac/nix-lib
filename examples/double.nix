# Example: using mkLibFromFile pattern with injected name
#
# This file is designed to be imported via mkLibFromFile:
#   mkLibFromFile ./examples/double.nix { }
#
# The `name` argument is automatically derived from the filename ("double")
{ lib, mkLib, name }:

mkLib {
  inherit name; # Use the injected name from filename
  type = lib.types.functionTo lib.types.int;
  fn = x: x * 2;
  description = "Double the input value";
  tests = {
    "doubles positive" = {
      args = {
        x = 5;
      };
      expected = 10;
    };
    "doubles zero" = {
      args = {
        x = 0;
      };
      expected = 0;
    };
    "doubles negative" = {
      args = {
        x = -3;
      };
      expected = -6;
    };
  };
}
