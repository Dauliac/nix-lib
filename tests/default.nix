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
  inherit (nlib)
    mkLib
    mkLibFromFile
    mkLibOption
    mkLibOptionFromFileName
    wrapLibModule
    backends
    coverage
    ;

  # Load example files using legacy mkLib
  legacyExamples = {
    add = import ../examples/add.nix { inherit lib mkLib; };
    identity = import ../examples/identity.nix { inherit lib mkLib; };
    myFunction = import ../examples/my-function.nix { inherit lib mkLib; };
  };

  # Load example using legacy mkLibFromFile
  legacyExamplesFromFile = {
    double = mkLibFromFile ../examples/double.nix { };
  };

  # Test new mkLibOption (returns { name = option })
  newExamples = {
    add = mkLibOption {
      name = "add";
      type = lib.types.functionTo (lib.types.functionTo lib.types.int);
      fn = a: b: a + b;
      description = "Add two integers";
      tests = {
        "basic" = {
          args = {
            a = 2;
            b = 3;
          };
          expected = 5;
          fn = args: args.a + args.b;
        };
      };
    };
  };

  # Test mkLibOptionFromFileName with wrapLibModule
  perLibModule = wrapLibModule ../examples/perLib/add.nix { };
in
{
  # ===== Legacy mkLib tests =====

  test_mkLib_creates_valid_structure = {
    expr = legacyExamples.add.name;
    expected = "add";
  };

  test_mkLib_includes_function = {
    expr = legacyExamples.add.fn 2 3;
    expected = 5;
  };

  test_mkLib_includes_tests = {
    expr = builtins.hasAttr "basic addition" legacyExamples.add.tests;
    expected = true;
  };

  test_mkLib_creates_option = {
    expr = builtins.hasAttr "option" legacyExamples.add;
    expected = true;
  };

  # ===== Legacy mkLibFromFile tests =====

  test_mkLibFromFile_derives_name = {
    expr = legacyExamplesFromFile.double.name;
    expected = "double";
  };

  test_mkLibFromFile_function_works = {
    expr = legacyExamplesFromFile.double.fn 7;
    expected = 14;
  };

  # ===== New mkLibOption tests =====

  test_mkLibOption_returns_attrset_with_name = {
    expr = builtins.hasAttr "add" newExamples.add;
    expected = true;
  };

  test_mkLibOption_has_nlib_metadata = {
    expr = builtins.hasAttr "_nlib" newExamples.add.add;
    expected = true;
  };

  test_mkLibOption_metadata_has_name = {
    expr = newExamples.add.add._nlib.name;
    expected = "add";
  };

  test_mkLibOption_metadata_has_fn = {
    expr = newExamples.add.add._nlib.fn 10 5;
    expected = 15;
  };

  test_mkLibOption_metadata_has_tests = {
    expr = builtins.hasAttr "basic" newExamples.add.add._nlib.tests;
    expected = true;
  };

  # ===== mkLibOptionFromFileName via wrapLibModule tests =====

  test_wrapLibModule_injects_mkLibOptionFromFileName = {
    expr = builtins.hasAttr "options" perLibModule;
    expected = true;
  };

  test_wrapLibModule_creates_lib_options = {
    expr = builtins.hasAttr "lib" perLibModule.options;
    expected = true;
  };

  test_wrapLibModule_derives_name_from_filename = {
    expr = builtins.hasAttr "add" perLibModule.options.lib;
    expected = true;
  };

  test_wrapLibModule_has_nlib_metadata = {
    expr = perLibModule.options.lib.add._nlib.name;
    expected = "add";
  };

  # ===== Backend tests =====

  test_backend_nix_unit_sanitizes_names = {
    expr = builtins.hasAttr "test_my_function_test_case" (
      backends.adapters.nix-unit legacyExamples.myFunction.name legacyExamples.myFunction.tests
    );
    expected = true;
  };

  # ===== Coverage tests =====

  test_coverage_calculate_empty = {
    expr = (coverage.calculate { }).percent;
    expected = 100;
  };

  test_coverage_calculate_with_libs = {
    expr = (coverage.calculate { inherit (legacyExamples) add identity; }).allTested;
    expected = true;
  };

  test_coverage_multiple_libs = {
    expr = (coverage.calculate legacyExamples).total;
    expected = 3;
  };

  # ===== Coverage with new format =====

  test_coverage_with_new_format = {
    expr = (coverage.calculate newExamples.add).total;
    expected = 1;
  };

  test_identity_function = {
    expr = legacyExamples.identity.fn 42;
    expected = 42;
  };
}
