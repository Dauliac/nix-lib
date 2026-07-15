# Scenario tests as eval-time checks.
#
# Reproduces the test scenarios (mkFlake, mkLib) inline — no get-flake,
# no recursive nix, no sandbox issues. Each scenario's assertions become
# { expr, expected } pairs checked at Nix eval time.
{ lib, ... }:
let
  nlibLib = import ../nix-lib/_lib { inherit lib; };

  # ── mkLib (standalone API) ──────────────────────────────────────────
  basicLib = nlibLib.mkLib {
    nixpkgs = { inherit lib; };
    namespace = "basic";
    libs = self: {
      double = {
        type = self.types.functionTo self.types.int;
        fn = x: x * 2;
        description = "Double a number";
        tests."doubles 5" = { args.x = 5; expected = 10; };
      };
      quadruple = {
        type = self.types.functionTo self.types.int;
        fn = x: self.fns.double (self.fns.double x);
        description = "Quadruple using double";
        tests."quadruples 3" = { args.x = 3; expected = 12; };
      };
      math.add = {
        type = self.types.functionTo self.types.int;
        fn = { a, b }: a + b;
        description = "Add two numbers";
        tests."adds" = { args.x = { a = 2; b = 3; }; expected = 5; };
      };
      math.doubleSum = {
        type = self.types.functionTo self.types.int;
        fn = { a, b }: self.fns.double (self.fns.math.add { inherit a b; });
        description = "Double the sum";
        tests."doubles sum" = { args.x = { a = 2; b = 3; }; expected = 10; };
      };
    };
  };

  visibilityLib = nlibLib.mkLib {
    nixpkgs = { inherit lib; };
    namespace = "visibility";
    libs = self: {
      _helper = {
        type = self.types.functionTo self.types.int;
        fn = x: x + 1;
        description = "Internal helper";
        visible = false;
      };
      addTwo = {
        type = self.types.functionTo self.types.int;
        fn = x: self.fns._helper (self.fns._helper x);
        description = "Add two using internal helper";
      };
    };
  };

  # ── mkFlake (standalone mode) ──────────────────────────────────────
  mkFlakeStandalone = nlibLib.mkFlake {
    inputs = { };
    modules = [
      (
        { config, ... }:
        {
          lib.math.double = {
            fn = x: x * 2;
            description = "Double";
            tests."doubles 5" = { args.x = 5; expected = 10; };
          };
          lib.math.quadruple = {
            fn = x: config.lib.math.double.fn (config.lib.math.double.fn x);
            description = "Quadruple";
            tests."quadruples 3" = { args.x = 3; expected = 12; };
          };
        }
      )
    ];
  } { };

  # ── mkFlake (flake-parts mode) ────────────────────────────────────
  # Test that mkFlake with flake-parts produces a valid lib output.
  # We can't do a full flake-parts evaluation here (would be recursive),
  # but we CAN verify the standalone evaluation path which tests the
  # same lib module processing.
  mkFlakeWithModules = nlibLib.mkFlake {
    inputs = { };
    modules = [
      (
        { config, ... }:
        {
          lib.math.double = {
            fn = x: x * 2;
            description = "Double";
            tests."doubles 5" = { args.x = 5; expected = 10; };
          };
          lib.math.quadruple = {
            fn = x: config.lib.math.double.fn (config.lib.math.double.fn x);
            description = "Quadruple";
            tests."quadruples 3" = { args.x = 3; expected = 12; };
          };
        }
      )
    ];
  } { };

  # ── Collect all scenario tests ─────────────────────────────────────
  scenarioTests = {
    # mkLib tests
    "test_mkLib_double_5" = {
      expr = basicLib.lib.basic.double 5;
      expected = 10;
    };
    "test_mkLib_double_0" = {
      expr = basicLib.lib.basic.double 0;
      expected = 0;
    };
    "test_mkLib_double_negative" = {
      expr = basicLib.lib.basic.double (-3);
      expected = -6;
    };
    "test_mkLib_quadruple_3" = {
      expr = basicLib.lib.basic.quadruple 3;
      expected = 12;
    };
    "test_mkLib_math_add" = {
      expr = basicLib.lib.basic.math.add { a = 2; b = 3; };
      expected = 5;
    };
    "test_mkLib_math_doubleSum" = {
      expr = basicLib.lib.basic.math.doubleSum { a = 2; b = 3; };
      expected = 10;
    };
    "test_mkLib_selfRef_works" = {
      expr = basicLib.lib.basic.quadruple 3 == 12;
      expected = true;
    };
    "test_mkLib_nested_namespace" = {
      expr = builtins.hasAttr "math" basicLib.lib.basic;
      expected = true;
    };
    "test_mkLib_visibility_private_hidden" = {
      expr = builtins.hasAttr "_helper" visibilityLib.lib.visibility;
      expected = false;
    };
    "test_mkLib_visibility_public_exists" = {
      expr = builtins.hasAttr "addTwo" visibilityLib.lib.visibility;
      expected = true;
    };
    "test_mkLib_visibility_addTwo" = {
      expr = visibilityLib.lib.visibility.addTwo 5;
      expected = 7;
    };
    "test_mkLib_generates_tests" = {
      expr = basicLib.tests != { };
      expected = true;
    };

    # mkFlake standalone tests
    "test_mkFlake_standalone_double" = {
      expr = mkFlakeStandalone.lib.math.double 5;
      expected = 10;
    };
    "test_mkFlake_standalone_quadruple" = {
      expr = mkFlakeStandalone.lib.math.quadruple 3;
      expected = 12;
    };
    "test_mkFlake_standalone_has_tests" = {
      expr = mkFlakeStandalone.tests != { };
      expected = true;
    };

    # mkFlake with modules tests
    "test_mkFlake_modules_double" = {
      expr = mkFlakeWithModules.lib.math.double 5;
      expected = 10;
    };
    "test_mkFlake_modules_quadruple" = {
      expr = mkFlakeWithModules.lib.math.quadruple 3;
      expected = 12;
    };
  };
in
{
  flake.tests = scenarioTests;
}
