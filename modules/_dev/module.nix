# Dev partition module — provides nixpkgs, treefmt, nix-unit, and devShell.
# The main evaluation is pure (no pkgs); this partition adds all dev tooling.
#
# Usage:
#   nix fmt              # format with treefmt
#   nix flake check      # includes format check
#   nix develop          # shell with nix-unit
#   nix build .#nix-lib-docs
#   nix run .#test-e2e
{ inputs, ... }:
{
  imports = [
    ../nix-lib/_default.nix
    ../_pkgs/e2e-tests.nix
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = inputs.nixpkgs.legacyPackages.${system};

      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
      };

      devShells.default = inputs.nixpkgs.legacyPackages.${system}.mkShell {
        packages = [
          inputs.nix-unit.packages.${system}.default
        ];
      };
    };
}
