# mkLib - Create tested, typed, documented library functions
#
# Returns a record with:
#   - name, fn, type, description: the lib definition
#   - tests: test cases in canonical format
#   - option: mkOption-compatible definition with auto-generated example
{ lib }:
let
  inherit (lib)
    mkOption
    types
    literalMD
    generators
    mapAttrsToList
    concatStringsSep
    optionalAttrs
    ;
  pretty = generators.toPretty { };

  # Generate example from tests as assertions
  mkExample =
    name: tests:
    literalMD ''
      ```nix
      ${concatStringsSep "\n" (
        mapAttrsToList (
          desc: t:
          "# ${desc}\nassert ${name} ${t.doc.args or pretty t.args} == ${
            t.doc.expected or pretty t.expected
          };"
        ) tests
      )}
      ```
    '';

  # Validation: type must be explicit (not lib.types.raw)
  requireExplicitType =
    type:
    if type == types.raw then
      throw "nlib.mkLib: explicit type required (lib.types.raw not allowed)"
    else
      type;

  # Validation: tests must not be empty
  requireTests =
    tests: if tests == { } then throw "nlib.mkLib: at least one test required" else tests;
in
{
  name,
  type,
  fn,
  tests,
  description,
  ...
}@args:
let
  validType = requireExplicitType type;
  validTests = requireTests tests;
in
{
  inherit name fn description;
  type = validType;
  tests = validTests;

  # mkOption-compatible definition
  option =
    mkOption {
      type = validType;
      inherit description;
      visible = args.visible or true;
      example = args.example or mkExample name validTests;
    }
    // optionalAttrs (args ? default) { default = args.default; }
    // optionalAttrs (args ? defaultText) { defaultText = args.defaultText; };
}
