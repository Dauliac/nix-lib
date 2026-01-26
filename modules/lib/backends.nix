# Test backend adapters
#
# Transforms canonical test format to framework-specific formats.
# All adapters have signature: name -> fn -> tests -> backendFormat
#
# Test cases only need: { args, expected }
# The fn comes from the lib definition, not each test case.
{ lib }:
let
  inherit (lib)
    mapAttrs'
    mapAttrsToList
    nameValuePair
    replaceStrings
    foldl'
    ;

  # Sanitize test name for use as identifier
  sanitize = s: replaceStrings [ " " ":" "-" "'" "\"" ] [ "_" "_" "_" "_" "_" ] s;

  # Extract nlib metadata from lib definition
  getMeta = def: def._nlib or def;

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

  # Backend adapters: name -> fn -> tests -> backendFormat
  adapters = {
    # nix-unit: { testName = { expr, expected } }
    nix-unit =
      name: fn: tests:
      mapAttrs' (
        desc: t:
        nameValuePair "test_${sanitize name}_${sanitize desc}" {
          expr = applyFn fn t.args;
          expected = t.expected;
        }
      ) tests;

    # nixt: describe/it blocks
    nixt =
      name: fn: tests:
      {
        block = [
          {
            describe = name;
            tests = mapAttrsToList (desc: t: {
              it = desc;
              expr = (applyFn fn t.args) == t.expected;
            }) tests;
          }
        ];
      };

    # nixtest (Jetify): [{ name, actual, expected }]
    nixtest =
      name: fn: tests:
      mapAttrsToList (desc: t: {
        name = "${name}: ${desc}";
        actual = applyFn fn t.args;
        expected = t.expected;
      }) tests;

    # lib.debug.runTests: { testName = { expr, expected } }
    runTests =
      name: fn: tests:
      mapAttrs' (
        desc: t:
        nameValuePair "${sanitize name}_${sanitize desc}" {
          expr = applyFn fn t.args;
          expected = t.expected;
        }
      ) tests;
  };
in
{
  inherit adapters;

  # Convert all libs to selected backend format
  toBackend =
    backend: libs:
    foldl' (
      acc: def:
      let
        meta = getMeta def;
      in
      acc // adapters.${backend} meta.name meta.fn meta.tests
    ) { } (builtins.attrValues libs);
}
