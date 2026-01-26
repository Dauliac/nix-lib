# Test backend adapters
#
# Transforms canonical test format to framework-specific formats.
# All adapters have signature: name -> tests -> backendFormat
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

  # Backend adapters
  adapters = {
    # nix-unit: { testName = { expr, expected } }
    nix-unit =
      name: tests:
      mapAttrs' (
        desc: t:
        nameValuePair "test_${sanitize name}_${sanitize desc}" {
          expr = t.fn t.args;
          expected = t.expected;
        }
      ) tests;

    # nixt: describe/it blocks
    nixt = name: tests: {
      block = [
        {
          describe = name;
          tests = mapAttrsToList (desc: t: {
            it = desc;
            expr = (t.fn t.args) == t.expected;
          }) tests;
        }
      ];
    };

    # nixtest (Jetify): [{ name, actual, expected }]
    nixtest =
      name: tests:
      mapAttrsToList (desc: t: {
        name = "${name}: ${desc}";
        actual = t.fn t.args;
        expected = t.expected;
      }) tests;

    # lib.debug.runTests: { testName = { expr, expected } }
    runTests =
      name: tests:
      mapAttrs' (
        desc: t:
        nameValuePair "${sanitize name}_${sanitize desc}" {
          expr = t.fn t.args;
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
    foldl' (acc: def: acc // adapters.${backend} def.name def.tests) { } (builtins.attrValues libs);
}
