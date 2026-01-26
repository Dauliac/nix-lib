# nlib self-tests
#
# Tests for nlib's own functionality using nix-unit format
# Example files are loaded from ../examples/
{
  pkgs ? import <nixpkgs> { },
}:
let
  lib = pkgs.lib;
  nlib = import ../lib { inherit lib; };
  inherit (nlib) mkLib backends coverage;

  # Load example files
  examples = {
    add = import ../examples/add.nix { inherit lib mkLib; };
    identity = import ../examples/identity.nix { inherit lib mkLib; };
    myFunction = import ../examples/my-function.nix { inherit lib mkLib; };
  };
in
{
  # Test mkLib creates valid structure
  test_mkLib_creates_valid_structure = {
    expr = examples.add.name;
    expected = "add";
  };

  # Test mkLib includes function
  test_mkLib_includes_function = {
    expr = examples.add.fn 2 3;
    expected = 5;
  };

  # Test mkLib includes tests
  test_mkLib_includes_tests = {
    expr = builtins.hasAttr "basic addition" examples.add.tests;
    expected = true;
  };

  # Test mkLib creates option
  test_mkLib_creates_option = {
    expr = builtins.hasAttr "option" examples.add;
    expected = true;
  };

  # Test coverage calculation with empty libs
  test_coverage_calculate_empty = {
    expr = (coverage.calculate { }).percent;
    expected = 100;
  };

  # Test coverage calculation with libs
  test_coverage_calculate_with_libs = {
    expr = (coverage.calculate { inherit (examples) add identity; }).allTested;
    expected = true;
  };

  # Test backends sanitize function names (hyphenated names)
  test_backend_nix_unit_sanitizes_names = {
    expr = builtins.hasAttr "test_my_function_test_case" (
      backends.adapters.nix-unit examples.myFunction.name examples.myFunction.tests
    );
    expected = true;
  };

  # Test identity function works correctly
  test_identity_function = {
    expr = examples.identity.fn 42;
    expected = 42;
  };

  # Test multiple libs coverage
  test_coverage_multiple_libs = {
    expr = (coverage.calculate examples).total;
    expected = 3;
  };
}
