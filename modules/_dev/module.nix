# Dev partition module — full dev tooling + tests as checks.
#
# Follows the nix-oci pattern: the dev partition imports examples,
# BDD tests, and all test-required inputs. Tests run as eval-time
# checks, not as apps with recursive nix.
#
# Usage:
#   nix flake check      # treefmt + unit tests + scenario tests (all as checks)
#   nix fmt              # auto-format
#   nix develop          # shell with nix-unit
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
    ../../tests/bdd/adapters.nix
    ../../tests/bdd/libDef.nix
    ../../tests/bdd/collectors.nix

    # Scenario tests — mkFlake, mkLib API tests as eval-time checks
    ./scenario-checks.nix
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
    };
}
