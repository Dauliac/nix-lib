# nlib self-tests
#
# Tests for nlib's own functionality using nix-unit format
{
  pkgs ? import <nixpkgs> { },
}:
let
  lib = pkgs.lib;
  nlib = import ../modules/lib { inherit lib; };
  inherit (nlib)
    mkLibOption
    mkLibOptionFromFileName
    wrapLibModule
    backends
    coverage
    ;

  # mkLibOption now returns a module: { options.lib.${name}, config._nlibMeta.${name} }
  # For testing, we need to extract the metadata from the module structure

  # Test data for mkLibOption
  addConfig = {
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

  identityConfig = {
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

  myFunctionConfig = {
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

  # Create modules from configs
  exampleAddModule = mkLibOption addConfig;
  exampleIdentityModule = mkLibOption identityConfig;
  exampleMyFunctionModule = mkLibOption myFunctionConfig;

  # For backend/coverage tests, we need metadata in the format expected by toBackend
  # toBackend expects: { libName = { _nlib = { name, fn, tests, ... } } }
  # or just: { libName = { name, fn, tests, ... } }
  mkMetaForTesting =
    config:
    {
      ${config.name} = {
        inherit (config)
          name
          fn
          tests
          description
          ;
      };
    };

  # Metadata for backend/coverage tests
  addMeta = mkMetaForTesting addConfig;
  identityMeta = mkMetaForTesting identityConfig;
  myFunctionMeta = mkMetaForTesting myFunctionConfig;
  allExamplesMeta = addMeta // identityMeta // myFunctionMeta;

  # Test mkLibOptionFromFileName with wrapLibModule
  perLibAddModule = wrapLibModule ../examples/add.nix { };
  perLibMultiplyModule = wrapLibModule ../examples/multiply.nix { };

  # Config with multiple assertions
  assertionsConfig = {
    name = "double";
    type = lib.types.functionTo lib.types.int;
    fn = x: x * 2;
    description = "Double the input";
    tests = {
      "comprehensive check" = {
        args = {
          x = 5;
        };
        assertions = [
          {
            name = "is positive";
            check = result: result > 0;
          }
          {
            name = "is even";
            check = result: lib.mod result 2 == 0;
          }
          {
            name = "equals 10";
            expected = 10;
          }
        ];
      };
    };
  };

  exampleWithAssertions = mkMetaForTesting assertionsConfig;

  # Config with mixed test formats (old and new)
  mixedConfig = {
    name = "triple";
    type = lib.types.functionTo lib.types.int;
    fn = x: x * 3;
    description = "Triple the input";
    tests = {
      "simple test" = {
        args.x = 3;
        expected = 9;
      };
      "with assertions" = {
        args.x = 4;
        assertions = [
          {
            name = "is 12";
            expected = 12;
          }
          {
            name = "divisible by 3";
            check = result: lib.mod result 3 == 0;
          }
        ];
      };
    };
  };

  exampleMixed = mkMetaForTesting mixedConfig;
in
{
  # ===== mkLibOption module structure tests =====

  test_mkLibOption_returns_module_with_options = {
    expr = builtins.hasAttr "options" exampleAddModule;
    expected = true;
  };

  test_mkLibOption_returns_module_with_config = {
    expr = builtins.hasAttr "config" exampleAddModule;
    expected = true;
  };

  test_mkLibOption_has_options_lib = {
    expr = builtins.hasAttr "lib" exampleAddModule.options;
    expected = true;
  };

  test_mkLibOption_has_options_lib_name = {
    expr = builtins.hasAttr "add" exampleAddModule.options.lib;
    expected = true;
  };

  test_mkLibOption_has_config_nlibMeta = {
    expr = builtins.hasAttr "_nlibMeta" exampleAddModule.config;
    expected = true;
  };

  test_mkLibOption_config_nlibMeta_has_name = {
    expr = builtins.hasAttr "add" exampleAddModule.config._nlibMeta;
    expected = true;
  };

  test_mkLibOption_metadata_has_name = {
    expr = exampleAddModule.config._nlibMeta.add.name;
    expected = "add";
  };

  test_mkLibOption_metadata_has_fn = {
    expr = exampleAddModule.config._nlibMeta.add.fn 10 5;
    expected = 15;
  };

  test_mkLibOption_metadata_has_tests = {
    expr = builtins.hasAttr "basic addition" exampleAddModule.config._nlibMeta.add.tests;
    expected = true;
  };

  test_mkLibOption_identity_works = {
    expr = exampleIdentityModule.config._nlibMeta.identity.fn 42;
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

  # wrapLibModule sets options.lib = mkLibOptionFromFileName {...}
  # which returns a module, so options.lib should have the function's attrs

  # ===== Backend tests =====

  test_backend_nix_unit_sanitizes_names = {
    expr = builtins.hasAttr "test_my_function_test_case" (
      backends.adapters.nix-unit myFunctionConfig.name myFunctionConfig.fn myFunctionConfig.tests
    );
    expected = true;
  };

  test_backend_nix_unit_generates_test = {
    expr =
      (backends.adapters.nix-unit addConfig.name addConfig.fn addConfig.tests)
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
    expr = (coverage.calculate allExamplesMeta).allTested;
    expected = true;
  };

  test_coverage_multiple_libs = {
    expr = (coverage.calculate allExamplesMeta).total;
    expected = 3;
  };

  test_coverage_with_single_lib = {
    expr = (coverage.calculate addMeta).total;
    expected = 1;
  };

  # ===== toBackend integration =====

  test_toBackend_converts_all_libs = {
    expr = builtins.hasAttr "test_add_basic_addition" (backends.toBackend "nix-unit" allExamplesMeta);
    expected = true;
  };

  test_toBackend_includes_identity = {
    expr = builtins.hasAttr "test_identity_returns_input" (
      backends.toBackend "nix-unit" allExamplesMeta
    );
    expected = true;
  };

  # ===== Multiple assertions tests =====

  test_assertions_expands_to_multiple_tests = {
    expr = builtins.length (builtins.attrNames (backends.toBackend "nix-unit" exampleWithAssertions));
    expected = 3;
  };

  test_assertions_creates_named_tests = {
    expr = builtins.hasAttr "test_double_comprehensive_check_is_positive" (
      backends.toBackend "nix-unit" exampleWithAssertions
    );
    expected = true;
  };

  test_assertions_check_passes = {
    expr =
      (backends.toBackend "nix-unit" exampleWithAssertions)
        .test_double_comprehensive_check_is_positive
        .expected;
    expected = true;
  };

  test_assertions_expected_value = {
    expr =
      (backends.toBackend "nix-unit" exampleWithAssertions)
        .test_double_comprehensive_check_equals_10
        .expected;
    expected = 10;
  };

  # ===== Lazy evaluation tests =====

  test_mkLazy_wraps_value = {
    expr = (backends.mkLazy 42).__lazy;
    expected = true;
  };

  test_force_unwraps_lazy = {
    expr = backends.force (backends.mkLazy 42);
    expected = 42;
  };

  test_force_passthrough_non_lazy = {
    expr = backends.force 42;
    expected = 42;
  };

  # ===== hasAssertions helper tests =====

  test_hasAssertions_true = {
    expr = backends.hasAssertions {
      args.x = 5;
      assertions = [
        { expected = 10; }
      ];
    };
    expected = true;
  };

  test_hasAssertions_false_for_expected = {
    expr = backends.hasAssertions {
      args.x = 5;
      expected = 10;
    };
    expected = false;
  };

  # ===== Mixed tests (old and new format together) =====

  test_mixed_expands_correctly = {
    expr = builtins.length (builtins.attrNames (backends.toBackend "nix-unit" exampleMixed));
    expected = 3; # 1 simple + 2 assertions
  };

  test_mixed_has_simple_test = {
    expr = builtins.hasAttr "test_triple_simple_test" (backends.toBackend "nix-unit" exampleMixed);
    expected = true;
  };

  test_mixed_has_assertion_test = {
    expr = builtins.hasAttr "test_triple_with_assertions_is_12" (
      backends.toBackend "nix-unit" exampleMixed
    );
    expected = true;
  };
}
