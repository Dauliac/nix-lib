# Dev partition module — full dev tooling + per-backend test checks.
#
# Each supported backend gets its own check derivation, run in parallel.
# An aggregation check gates them all for `nix flake check`.
#
# Usage:
#   nix flake check              # treefmt + all backend tests (parallel)
#   nix fmt                      # auto-format
#   nix develop                  # shell with nix-unit
#   nix build .#nix-lib-docs
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
    ../../tests/bdd/libDef.nix
    ../../tests/bdd/collectors.nix

    # Scenario tests — mkFlake, mkLib, backend format checks
    ./scenario-checks.nix
  ];

  perSystem =
    { system, lib, ... }:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};

      # ── Test data ──────────────────────────────────────────────────
      # All { expr, expected } tests from flake.tests (BDD + scenario + auto-generated).
      # Filtered to JSON-serializable values only.
      isJsonSafe =
        v:
        builtins.isInt v
        || builtins.isBool v
        || builtins.isString v
        || builtins.isFloat v
        || v == null
        || (builtins.isList v && builtins.all isJsonSafe v)
        || (builtins.isAttrs v && !(v ? outPath) && builtins.all isJsonSafe (builtins.attrValues v));

      allTests = lib.filterAttrs (
        _: test: test ? expr && test ? expected && isJsonSafe test.expr && isJsonSafe test.expected
      ) (config.flake.tests or { });
      testCount = builtins.length (builtins.attrNames allTests);

      testsJson = pkgs.writeText "tests.json" (builtins.toJSON allTests);

      # ── Per-backend checks ─────────────────────────────────────────

      # 1. nix-unit: real CLI via JSON serialization
      check-nix-unit =
        pkgs.runCommand "check-nix-unit"
          {
            nativeBuildInputs = [
              inputs.nix-unit.packages.${system}.default
              pkgs.nix
            ];
          }
          ''
            export HOME=$(mktemp -d)
            echo "nix-unit: running ${toString testCount} tests..."
            nix-unit --expr "builtins.fromJSON (builtins.readFile ${testsJson})"
            echo "nix-unit: ${toString testCount} tests passed"
            touch $out
          '';

      # 2. runTests: pure Nix lib.debug.runTests (eval-time)
      runTestsResults = lib.debug.runTests allTests;
      check-runTests =
        if runTestsResults != [ ] then
          throw "runTests: ${toString (builtins.length runTestsResults)} failures: ${
            builtins.toJSON (map (f: f.name) runTestsResults)
          }"
        else
          pkgs.runCommand "check-runTests" { } ''
            echo "runTests: ${toString testCount} tests passed"
            touch $out
          '';

      # 3. nix-tests: real CLI with test file
      nixTestsFile = pkgs.writeText "nix-tests-suite.nix" ''
        let
          tests = builtins.fromJSON (builtins.readFile ${testsJson});
        in
        {
          "nix-lib" = helpers:
            builtins.mapAttrs (name: test:
              helpers.isEq test.expr test.expected
            ) tests;
        }
      '';
      check-nix-tests =
        pkgs.runCommand "check-nix-tests"
          {
            nativeBuildInputs = [
              inputs.nix-tests.packages.${system}.default
              pkgs.nix
            ];
          }
          ''
            export HOME=$(mktemp -d)
            echo "nix-tests: running ${toString testCount} tests..."
            nix-tests ${nixTestsFile}
            echo "nix-tests: passed"
            touch $out
          '';
    in
    {
      _module.args.pkgs = pkgs;

      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
      };

      # Disable nix-unit module's own check (uses --flake, needs git in sandbox)
      checks.nix-unit = lib.mkForce (pkgs.runCommand "nix-unit-skip" { } "touch $out");

      # All backends tested in parallel via a single aggregation derivation.
      checks.tests = pkgs.runCommand "tests" { } ''
        mkdir -p $out
        ln -s ${check-nix-unit} $out/nix-unit
        ln -s ${check-runTests} $out/runTests
        ln -s ${check-nix-tests} $out/nix-tests
      '';

      devShells.default = pkgs.mkShell {
        packages = [
          inputs.nix-unit.packages.${system}.default
          inputs.nix-tests.packages.${system}.default
        ];
      };
    };
}
