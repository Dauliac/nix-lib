# nlib self-tests
#
# Tests for nlib's own functionality using nix-unit format
{
  pkgs ? import <nixpkgs> { },
}:
let
  lib = pkgs.lib;
  nlib = import ../lib { inherit lib; };
  inherit (nlib)
    mkLibOption
    mkLibOptionFromFileName
    wrapLibModule
    backends
    coverage
    ;

  # Test mkLibOption (returns { name = option })
  exampleAdd = mkLibOption {
    name = "add";
    type = lib.types.functionTo (lib.types.functionTo lib.types.int);
    fn = a: b: a + b;
    description = "Add two integers";
    tests = {
      "basic addition" = {
        args = {
          a = 2;
          b = 3;
        };
        expected = 5;
      };
      "with zero" = {
        args = {
          a = 5;
          b = 0;
        };
        expected = 5;
      };
    };
  };

  exampleIdentity = mkLibOption {
    name = "identity";
    type = lib.types.functionTo lib.types.int;
    fn = x: x;
    description = "Return input unchanged";
    tests = {
      "returns input" = {
        args = {
          x = 42;
        };
        expected = 42;
      };
    };
  };

  exampleMyFunction = mkLibOption {
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
  };

  # Collect all examples for coverage/backend tests
  allExamples = exampleAdd // exampleIdentity // exampleMyFunction;

  # Test mkLibOptionFromFileName with wrapLibModule
  perLibAddModule = wrapLibModule ../examples/add.nix { };
  perLibMultiplyModule = wrapLibModule ../examples/multiply.nix { };
in
{
  # ===== mkLibOption tests =====

  test_mkLibOption_returns_attrset_with_name = {
    expr = builtins.hasAttr "add" exampleAdd;
    expected = true;
  };

  test_mkLibOption_has_nlib_metadata = {
    expr = builtins.hasAttr "_nlib" exampleAdd.add;
    expected = true;
  };

  test_mkLibOption_metadata_has_name = {
    expr = exampleAdd.add._nlib.name;
    expected = "add";
  };

  test_mkLibOption_metadata_has_fn = {
    expr = exampleAdd.add._nlib.fn 10 5;
    expected = 15;
  };

  test_mkLibOption_metadata_has_tests = {
    expr = builtins.hasAttr "basic addition" exampleAdd.add._nlib.tests;
    expected = true;
  };

  test_mkLibOption_identity_works = {
    expr = exampleIdentity.identity._nlib.fn 42;
    expected = 42;
  };

  # ===== mkLibOptionFromFileName via wrapLibModule tests =====

  test_wrapLibModule_injects_mkLibOptionFromFileName = {
    expr = builtins.hasAttr "options" perLibAddModule;
    expected = true;
  };

  test_wrapLibModule_creates_lib_options = {
    expr = builtins.hasAttr "lib" perLibAddModule.options;
    expected = true;
  };

  test_wrapLibModule_derives_name_from_filename = {
    expr = builtins.hasAttr "add" perLibAddModule.options.lib;
    expected = true;
  };

  test_wrapLibModule_has_nlib_metadata = {
    expr = perLibAddModule.options.lib.add._nlib.name;
    expected = "add";
  };

  test_wrapLibModule_multiply_derives_name = {
    expr = builtins.hasAttr "multiply" perLibMultiplyModule.options.lib;
    expected = true;
  };

  # ===== Backend tests =====

  test_backend_nix_unit_sanitizes_names = {
    expr = builtins.hasAttr "test_my_function_test_case" (
      backends.adapters.nix-unit
        exampleMyFunction."my-function"._nlib.name
        exampleMyFunction."my-function"._nlib.fn
        exampleMyFunction."my-function"._nlib.tests
    );
    expected = true;
  };

  test_backend_nix_unit_generates_test = {
    expr =
      (backends.adapters.nix-unit "add" exampleAdd.add._nlib.fn exampleAdd.add._nlib.tests)
        .test_add_basic_addition
        .expected;
    expected = 5;
  };

  # ===== Coverage tests =====

  test_coverage_calculate_empty = {
    expr = (coverage.calculate { }).percent;
    expected = 100;
  };

  test_coverage_calculate_with_libs = {
    expr = (coverage.calculate allExamples).allTested;
    expected = true;
  };

  test_coverage_multiple_libs = {
    expr = (coverage.calculate allExamples).total;
    expected = 3;
  };

  test_coverage_with_single_lib = {
    expr = (coverage.calculate exampleAdd).total;
    expected = 1;
  };

  # ===== toBackend integration =====

  test_toBackend_converts_all_libs = {
    expr = builtins.hasAttr "test_add_basic_addition" (backends.toBackend "nix-unit" allExamples);
    expected = true;
  };

  test_toBackend_includes_identity = {
    expr = builtins.hasAttr "test_identity_returns_input" (backends.toBackend "nix-unit" allExamples);
    expected = true;
  };
}
