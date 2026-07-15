# Dev partition module — full dev tooling + tests as checks.
#
# Follows the nix-oci pattern: the dev partition imports examples,
# BDD tests, and all test-required inputs. Tests run as eval-time
# checks, not as apps with recursive nix.
#
# Usage:
#   nix flake check      # treefmt + 46 unit tests (all as checks)
#   nix fmt              # auto-format
#   nix develop          # shell with nix-unit
#   nix build .#nix-lib-docs
#   nix run .#test-e2e   # full scenario suite (mkFlake, mkLib, backends)
{ inputs, config, ... }:
{
  imports = [
    ../nix-lib/_default.nix
    inputs.treefmt-nix.flakeModule
    inputs.nix-unit.modules.flake.default

    # Full integration examples — creates nixosConfigurations,
    # homeConfigurations, etc. for BDD + unit tests to validate.
    ../../examples/full-integration.nix

    # BDD tests — pure Nix assertions about library structure
    ../../tests/bdd/adapters.nix
    ../../tests/bdd/libDef.nix
    ../../tests/bdd/collectors.nix
  ];

  perSystem =
    { system, lib, ... }:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};

      # All { expr, expected } test entries from flake.tests (BDD + auto-generated)
      allTests = lib.filterAttrs (_: test: test ? expr && test ? expected) (config.flake.tests or { });
      failures = lib.filterAttrs (_: test: test.expr != test.expected) allTests;
      testCount = builtins.length (builtins.attrNames allTests);
      failCount = builtins.length (builtins.attrNames failures);
    in
    {
      _module.args.pkgs = pkgs;

      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
      };

      # Disable nix-unit's own check (needs nix evaluator inside sandbox)
      checks.nix-unit = lib.mkForce (pkgs.runCommand "nix-unit-skip" { } "touch $out");

      # Eval-time unit tests — all { expr, expected } pairs from BDD + lib tests.
      # Failures are caught at Nix eval time, before any derivation builds.
      checks.unit-tests =
        if failures != { } then
          throw "Unit tests failed (${toString failCount}/${toString testCount}): ${builtins.concatStringsSep ", " (builtins.attrNames failures)}"
        else
          pkgs.runCommand "unit-tests-pass" { } ''
            echo "${toString testCount} tests passed"
            touch $out
          '';

      devShells.default = pkgs.mkShell {
        packages = [
          inputs.nix-unit.packages.${system}.default
        ];
      };

      # E2E test runner — runs scenario subflakes that test alternative APIs
      # (mkFlake, mkLib) and backend compatibility (nix-tests).
      # These need recursive nix and can't be sandbox checks.
      apps.test-e2e =
        let
          scenarios = [
            "nix-unit"
            "nix-tests"
            "standalone"
            "mkFlake-flake-parts"
            "mkFlake-standalone"
          ];
          scenarioList = builtins.concatStringsSep " " scenarios;
          testScript = pkgs.writeShellApplication {
            name = "test-e2e";
            runtimeInputs = [
              pkgs.nix
              pkgs.coreutils
            ];
            text = ''
              set -euo pipefail
              SCENARIOS_DIR="''${1:-./tests/scenarios}"
              SCENARIOS=(${scenarioList})
              echo "=== Running E2E test scenarios ==="
              echo ""
              PASSED=0
              FAILED=0
              FAILED_SCENARIOS=()
              for scenario in "''${SCENARIOS[@]}"; do
                SCENARIO_PATH="$SCENARIOS_DIR/$scenario"
                if [[ ! -d "$SCENARIO_PATH" ]]; then
                  echo "⚠ Skipping $scenario (directory not found)"
                  continue
                fi
                echo "▶ Running scenario: $scenario"
                if nix run "$SCENARIO_PATH#test" 2>&1 | sed 's/^/  /'; then
                  echo "✓ $scenario passed"
                  ((PASSED++))
                else
                  echo "✗ $scenario failed"
                  ((FAILED++))
                  FAILED_SCENARIOS+=("$scenario")
                fi
                echo ""
              done
              echo "=== E2E Test Summary ==="
              echo "Passed: $PASSED"
              echo "Failed: $FAILED"
              if [[ $FAILED -gt 0 ]]; then
                echo ""
                echo "Failed scenarios:"
                for s in "''${FAILED_SCENARIOS[@]}"; do
                  echo "  - $s"
                done
                exit 1
              fi
              echo ""
              echo "=== All E2E tests passed! ==="
            '';
          };
        in
        {
          type = "app";
          program = "${testScript}/bin/test-e2e";
        };
    };
}
