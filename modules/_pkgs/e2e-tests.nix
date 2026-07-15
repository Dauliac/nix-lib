# E2E test runner - runs all test scenarios
{ ... }:
{
  perSystem =
    { pkgs, ... }:
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
        runtimeInputs = with pkgs; [
          nix
          coreutils
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

          # Run linter-fail scenario (shell script based)
          LINTER_FAIL_PATH="$SCENARIOS_DIR/linter-fail"
          if [[ -x "$LINTER_FAIL_PATH/run-test.sh" ]]; then
            echo "▶ Running scenario: linter-fail"
            if (cd "$LINTER_FAIL_PATH" && ./run-test.sh) 2>&1 | sed 's/^/  /'; then
              echo "✓ linter-fail passed"
              ((PASSED++))
            else
              echo "✗ linter-fail failed"
              ((FAILED++))
              FAILED_SCENARIOS+=("linter-fail")
            fi
            echo ""
          fi

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
      apps.test-e2e = {
        type = "app";
        program = "${testScript}/bin/test-e2e";
      };
    };
}
