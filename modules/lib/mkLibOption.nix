# mkLibOption - Create mergeable lib option for options.lib
#
# Returns a module with both options.lib and config._nlibMeta for test extraction.
# Multiple mkLibOption calls merge together in the module system.
#
# Test formats supported:
# 1. Simple expected value:
#    tests."test name" = { args.x = 5; expected = 10; };
#
# 2. Multiple assertions (evaluated lazily):
#    tests."test name" = {
#      args.x = 5;
#      assertions = [
#        { name = "is positive"; check = result: result > 0; }
#        { name = "equals 10"; expected = 10; }
#      ];
#    };
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
    optionalString
    hasAttr
    isList
    length
    ;
  pretty = generators.toPretty { };

  # Check if test uses assertions format
  hasAssertions = t: hasAttr "assertions" t && isList t.assertions;

  # Format a single assertion for documentation
  formatAssertion =
    assertion:
    if hasAttr "expected" assertion then
      "== ${pretty assertion.expected}"
    else if hasAttr "check" assertion then
      "passes ${assertion.name or "check"}"
    else
      "??";

  # Generate example from tests as assertions
  mkTestsExample =
    name: tests:
    ''
      ```nix
      ${concatStringsSep "\n" (
        mapAttrsToList (
          desc: t:
          if hasAssertions t then
            "# ${desc}\nlet result = ${name} ${t.doc.args or pretty t.args}; in\n${
              concatStringsSep "\n" (
                map (
                  a:
                  if hasAttr "expected" a then
                    "assert result == ${pretty a.expected}; # ${a.name or "check"}"
                  else
                    "assert ${a.name or "check"} result; # ${a.name or "predicate"}"
                ) t.assertions
              )
            }"
          else
            "# ${desc}\nassert ${name} ${t.doc.args or pretty t.args} == ${t.doc.expected or pretty t.expected};"
        ) tests
      )}
      ```
    '';

  # Merge user example with auto-generated tests example
  mkExample =
    name: tests: userExample:
    literalMD (
      optionalString (userExample != null) ''
        ${userExample}

      ''
      + mkTestsExample name tests
    );

  # Validation: type must be explicit (not lib.types.raw)
  requireExplicitType =
    type:
    if type == types.raw then
      throw "nlib.mkLibOption: explicit type required (lib.types.raw not allowed)"
    else
      type;

  # Validation: tests must not be empty
  requireTests =
    tests:
    if tests == { } then throw "nlib.mkLibOption: at least one test required" else tests;

  # Validation: assertions must have either expected or check
  validateAssertions =
    tests:
    let
      invalid = builtins.filter (
        desc:
        let
          t = tests.${desc};
        in
        hasAssertions t
        && builtins.any (a: !(hasAttr "expected" a) && !(hasAttr "check" a)) t.assertions
      ) (builtins.attrNames tests);
    in
    if invalid != [ ] then
      throw "nlib.mkLibOption: assertions must have 'expected' or 'check' attribute in: ${concatStringsSep ", " invalid}"
    else
      tests;
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
  validTests = validateAssertions (requireTests tests);

  option =
    mkOption {
      type = validType;
      inherit description;
      default = fn;
      visible = args.visible or true;
      example = mkExample name validTests (args.example or null);
    }
    // optionalAttrs (args ? defaultText) { inherit (args) defaultText; };

  # Metadata for test extraction (stored in config, survives module evaluation)
  meta = {
    inherit name fn description;
    type = validType;
    tests = validTests;
  };
in
{
  # Return a module that sets both option and metadata
  options.lib.${name} = option;

  # Store metadata in config for test extraction
  config._nlibMeta.${name} = meta;
}
