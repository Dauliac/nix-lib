# Dev partition module — provides nixpkgs, treefmt, nix-unit, and devShell.
# The main evaluation is pure (no pkgs); this partition adds all dev tooling.
#
# Usage:
#   nix flake check      # format check (treefmt)
#   nix fmt              # auto-format with treefmt
#   nix develop          # shell with nix-unit (for interactive testing)
#   nix build .#nix-lib-docs
#   nix run .#test-e2e   # E2E integration tests (runs all test scenarios)
#
# Tests are run via test scenarios (tests/scenarios/*/), not as checks,
# because they need recursive nix evaluation and extra inputs (home-manager,
# nixvim, etc.) that aren't in the main flake.
{ inputs, ... }:
{
  imports = [
    ../nix-lib/_default.nix
    ../_pkgs/e2e-tests.nix
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    { system, ... }:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    {
      _module.args.pkgs = pkgs;

      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
      };

      devShells.default = pkgs.mkShell {
        packages = [
          inputs.nix-unit.packages.${system}.default
        ];
      };
    };
}
