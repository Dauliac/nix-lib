# nlib self-tests
#
# Tests for nlib's own functionality using nix-unit format
{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  nlib = import ../modules/nlib/_lib { inherit lib; };
  inherit (nlib) backends coverage;

  # Test metadata (simulates what libDefType produces)
  addMeta = {
    add = {
      name = "add";
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
  };

  identityMeta = {
    identity = {
      name = "identity";
      fn = x: x;
      description = "Return input unchanged";
      tests = {
        "returns input" = {
          args.x = 42;
          expected = 42;
        };
      };
    };
  };

  myFunctionMeta = {
    my-function = {
      name = "my-function";
      fn = x: x * 2;
      description = "Double the input";
      tests = {
        "test case" = {
          args.x = 5;
          expected = 10;
        };
      };
    };
  };

  allExamplesMeta = addMeta // identityMeta // myFunctionMeta;

  # Metadata with multiple assertions
  assertionsMeta = {
    double = {
      name = "double";
      fn = x: x * 2;
      description = "Double the input";
      tests = {
        "comprehensive check" = {
          args.x = 5;
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
  };

  # Metadata with mixed test formats
  mixedMeta = {
    triple = {
      name = "triple";
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
  };
in
{
  # ===== Backend tests =====

  test_backend_nix_unit_sanitizes_names = {
    expr = builtins.hasAttr "test_my_function_test_case" (
      backends.adapters.nix-unit "my-function" myFunctionMeta.my-function.fn
        myFunctionMeta.my-function.tests
    );
    expected = true;
  };

  test_backend_nix_unit_generates_test = {
    expr =
      (backends.adapters.nix-unit "add" addMeta.add.fn addMeta.add.tests)
      .test_add_basic_addition.expected;
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
    expr = builtins.length (builtins.attrNames (backends.toBackend "nix-unit" assertionsMeta));
    expected = 3;
  };

  test_assertions_creates_named_tests = {
    expr = builtins.hasAttr "test_double_comprehensive_check_is_positive" (
      backends.toBackend "nix-unit" assertionsMeta
    );
    expected = true;
  };

  test_assertions_check_passes = {
    expr =
      (backends.toBackend "nix-unit" assertionsMeta).test_double_comprehensive_check_is_positive.expected;
    expected = true;
  };

  test_assertions_expected_value = {
    expr =
      (backends.toBackend "nix-unit" assertionsMeta).test_double_comprehensive_check_equals_10.expected;
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
    expr = builtins.length (builtins.attrNames (backends.toBackend "nix-unit" mixedMeta));
    expected = 3; # 1 simple + 2 assertions
  };

  test_mixed_has_simple_test = {
    expr = builtins.hasAttr "test_triple_simple_test" (backends.toBackend "nix-unit" mixedMeta);
    expected = true;
  };

  test_mixed_has_assertion_test = {
    expr = builtins.hasAttr "test_triple_with_assertions_is_12" (
      backends.toBackend "nix-unit" mixedMeta
    );
    expected = true;
  };
}
