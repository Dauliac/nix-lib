# nlib perSystem flake.parts module
#
# Defines config.lib for per-system libs inside the perSystem block:
#
#   perSystem = { pkgs, lib, config, ... }: {
#     lib.writeGreeting = {
#       type = lib.types.functionTo lib.types.package;
#       fn = name: pkgs.writeText "greeting" "Hello, ${name}!";
#       description = "Write a greeting file";
#       tests."greets Alice" = { args.name = "Alice"; expected = "greeting-Alice"; };
#     };
#   };
#
{ lib, config, ... }:
let
  nlibLib = import ../lib { inherit lib; };
  libDefType = import ../lib/libDefType.nix { inherit lib; };
  testingCfg = config.nlib.testing or { };
in
{
  perSystem =
    { pkgs, system, lib, config, ... }:
    let
      # Convert lib definitions to metadata format
      libDefsToMeta =
        defs:
        lib.mapAttrs (
          name: def: {
            inherit name;
            inherit (def) fn description type;
            tests = lib.mapAttrs (_: t: {
              args = t.args;
              expected = t.expected;
              assertions = t.assertions;
            }) def.tests;
          }
        ) defs;

      # Extract plain functions
      extractFns = defs: lib.mapAttrs (_: def: def.fn) defs;

      # Get lib definitions from config.lib
      perSystemLibDefs = config.lib or { };
      perSystemMeta = libDefsToMeta perSystemLibDefs;
      perSystemFns = extractFns perSystemLibDefs;

      # Test runner configuration
      reporter = testingCfg.reporter or "default";
      outputPath = testingCfg.outputPath or "test-results.xml";
      namespace = config.nlib.namespace or "lib";

      # Test runner script
      mkTestRunner =
        nixUnit:
        pkgs.writeShellScriptBin "nlib-test" ''
          set -euo pipefail

          FLAKE_REF="''${1:-.}"
          OUTPUT_FILE="''${2:-${outputPath}}"
          REPORTER="${reporter}"

          # Build the test command
          TEST_EXPR="$FLAKE_REF#tests.${namespace}"

          echo "Running tests: nix-unit --flake $TEST_EXPR"

          if [[ "$REPORTER" == "junit" ]]; then
            echo "JUnit output enabled - writing to $OUTPUT_FILE"
            ${nixUnit}/bin/nix-unit --flake "$TEST_EXPR" | tee "$OUTPUT_FILE.log"
            echo "Test log written to: $OUTPUT_FILE.log"
            echo "Note: Native JUnit XML format requires nix-unit JUnit reporter support"
          else
            ${nixUnit}/bin/nix-unit --flake "$TEST_EXPR"
          fi
        '';
    in
    {
      # Define options.lib for per-system libs
      options.lib = lib.mkOption {
        type = lib.types.attrsOf libDefType;
        default = { };
        description = ''
          Per-system lib definitions. Use for libs that depend on pkgs.

          Usage:
          ```nix
          perSystem = { pkgs, lib, config, ... }: {
            lib.writeGreeting = {
              type = lib.types.functionTo lib.types.package;
              fn = name: pkgs.writeText "greeting" "Hello, ''${name}!";
              description = "Write a greeting file";
              tests."greets Alice" = { args.name = "Alice"; expected = "greeting-Alice"; };
            };
          };
          ```
        '';
      };

      options.nlib.namespace = lib.mkOption {
        type = lib.types.str;
        default = "lib";
        description = "Namespace for this system's libs in flake.lib output";
      };

      # Export evaluated libs and utilities
      config = {
        # Auto-expose to legacyPackages.nlib for external access
        legacyPackages.nlib = perSystemFns;

        # Keep internal access for backwards compatibility
        _module.args._nlibPerSystem = {
          libs = perSystemLibDefs;
          meta = perSystemMeta;
          fns = perSystemFns;
        };

        _module.args._nlibMkTestRunner = mkTestRunner;
      };
    };
}
