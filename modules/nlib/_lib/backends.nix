# Test backend adapters
#
# Transforms canonical test format to framework-specific formats.
# All adapters have signature: name -> fn -> tests -> backendFormat
#
# Test formats supported:
# 1. Simple expected value:
#    tests."test name" = { args.x = 5; expected = 10; };
#
# 2. Multiple assertions:
#    tests."test name" = {
#      args.x = 5;
#      assertions = [
#        { name = "is positive"; check = result: result > 0; }
#        { name = "equals 10"; expected = 10; }
#      ];
#    };
#
# Lazy evaluation: Tests are wrapped as thunks and only evaluated when needed.
{ lib }:
let
  libDefTypeModule = import ./libDefType.nix { inherit lib; };
  inherit (libDefTypeModule) getMeta;

  inherit (lib)
    mapAttrsToList
    replaceStrings
    foldl'
    concatLists
    isList
    hasAttr
    ;

  # Sanitize test name for use as identifier
  sanitize = s: replaceStrings [ " " ":" "-" "'" "\"" ] [ "_" "_" "_" "_" "_" ] s;

  # Apply function to args (handles both curried and attrset args)
  applyFn =
    fn: args:
    if builtins.isAttrs args then
      let
        argNames = builtins.attrNames args;
      in
      builtins.foldl' (f: name: f args.${name}) fn argNames
    else
      fn args;

  # Lazy wrapper - defers evaluation until result is accessed
  # This prevents tests from being evaluated during flake evaluation
  mkLazy = thunk: {
    __lazy = true;
    __thunk = thunk;
  };

  # Force evaluation of a lazy value
  force = v: if v ? __lazy && v.__lazy then v.__thunk else v;

  # Check if test uses assertions format (must be non-empty list)
  hasAssertions = t: hasAttr "assertions" t && isList t.assertions && t.assertions != [ ];

  # Expand a single test into multiple tests (one per assertion)
  # Returns: [{ testName, testSpec }]
  expandTest =
    name: desc: fn: t:
    let
      result = mkLazy (applyFn fn t.args);
    in
    if hasAssertions t then
      # Multiple assertions: create one test per assertion
      builtins.genList (
        i:
        let
          assertion = builtins.elemAt t.assertions i;
          assertName = assertion.name or "assertion_${toString i}";
        in
        {
          testName = "test_${sanitize name}_${sanitize desc}_${sanitize assertName}";
          testSpec =
            if hasAttr "expected" assertion then
              # Assertion with expected value
              {
                expr = force result;
                inherit (assertion) expected;
              }
            else if hasAttr "check" assertion then
              # Assertion with check function
              {
                expr = assertion.check (force result);
                expected = true;
              }
            else
              throw "nlib: assertion must have 'expected' or 'check' attribute";
        }
      ) (builtins.length t.assertions)
    else
      # Simple expected value: single test
      [
        {
          testName = "test_${sanitize name}_${sanitize desc}";
          testSpec = {
            expr = force result;
            inherit (t) expected;
          };
        }
      ];

  # Backend adapters: name -> fn -> tests -> backendFormat
  adapters = {
    # nix-unit: { testName = { expr, expected } }
    nix-unit =
      name: fn: tests:
      let
        expanded = concatLists (mapAttrsToList (desc: t: expandTest name desc fn t) tests);
      in
      foldl' (acc: test: acc // { ${test.testName} = test.testSpec; }) { } expanded;

    # nixt: describe/it blocks
    nixt =
      name: fn: tests:
      let
        expanded = concatLists (mapAttrsToList (desc: t: expandTest name desc fn t) tests);
      in
      {
        block = [
          {
            describe = name;
            tests = map (test: {
              it = test.testName;
              expr = test.testSpec.expr == test.testSpec.expected;
            }) expanded;
          }
        ];
      };

    # nixtest (Jetify): [{ name, actual, expected }]
    nixtest =
      name: fn: tests:
      let
        expanded = concatLists (mapAttrsToList (desc: t: expandTest name desc fn t) tests);
      in
      map (test: {
        name = test.testName;
        actual = test.testSpec.expr;
        inherit (test.testSpec) expected;
      }) expanded;

    # lib.debug.runTests: { testName = { expr, expected } }
    runTests =
      name: fn: tests:
      let
        expanded = concatLists (mapAttrsToList (desc: t: expandTest name desc fn t) tests);
      in
      foldl' (acc: test: acc // { ${test.testName} = test.testSpec; }) { } expanded;
  };
in
{
  inherit
    adapters
    mkLazy
    force
    hasAssertions
    expandTest
    ;

  # Convert all libs to selected backend format
  toBackend =
    backend: libs:
    foldl' (
      acc: def:
      let
        meta = getMeta def;
        tests = meta.tests or { };
      in
      if tests == { } then acc else acc // adapters.${backend} meta.name meta.fn tests
    ) { } (builtins.attrValues libs);
}
