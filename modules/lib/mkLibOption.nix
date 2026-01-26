# mkLibOption - Create mergeable lib option for options.lib
#
# Returns { "${name}" = mkOption { ... }; } for spreading into options.lib
# Multiple mkLibOption calls merge together in the module system.
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
    ;
  pretty = generators.toPretty { };

  # Generate example from tests as assertions
  mkTestsExample =
    name: tests:
    ''
      ```nix
      ${concatStringsSep "\n" (
        mapAttrsToList (
          desc: t:
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

  option =
    mkOption {
      type = validType;
      inherit description;
      default = fn;
      visible = args.visible or true;
      example = mkExample name validTests (args.example or null);
    }
    // optionalAttrs (args ? defaultText) { inherit (args) defaultText; };
in
{
  ${name} = option // {
    # Attach metadata for test extraction
    _nlib = {
      inherit name fn description;
      type = validType;
      tests = validTests;
    };
  };
}
