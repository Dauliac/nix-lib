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
      testCount = builtins.length (builtins.attrNames allTests);
    in
    {
      _module.args.pkgs = pkgs;

      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
      };

      # Disable nix-unit's flake-based check (needs flake resolution in sandbox).
      # We replace it with a direct nix-unit check below.
      checks.nix-unit = lib.mkForce (
        let
          nix-unit = inputs.nix-unit.packages.${system}.default;
          # Serialize tests to JSON, then nix-unit reads them back via fromJSON.
          # This avoids --flake (which needs git/network) while still exercising
          # the real nix-unit CLI and its Nix evaluator.
          testsJson = pkgs.writeText "tests.json" (builtins.toJSON allTests);
        in
        pkgs.runCommand "nix-unit" {
          nativeBuildInputs = [
            nix-unit
            pkgs.nix
          ];
        } ''
          export HOME=$(mktemp -d)
          echo "Running ${toString testCount} tests through nix-unit..."
          nix-unit --expr "builtins.fromJSON (builtins.readFile ${testsJson})"
          touch $out
        ''
      );

      devShells.default = pkgs.mkShell {
        packages = [
          inputs.nix-unit.packages.${system}.default
        ];
      };
    };
}
