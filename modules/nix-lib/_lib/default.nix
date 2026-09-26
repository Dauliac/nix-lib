# nix-lib - Nix library utilities
#
# Exports:
#   - mkFlake: Create flakes with lib modules (wraps flake-parts optionally)
#   - evalLibModules: Evaluate lib modules into functions/tests/meta
#   - mkAdapter: Factory to create adapters for any module system
#   - mkLib: Create typed libs for non-flake-parts flakes
#   - mkSpecialArgsLib: Extract functions for flake-parts specialArgs injection
#   - withLib: Composable facade for options-phase lib injection
#   - backends: Test backend adapters (nix-unit, nixt, nixtest, runTests)
#   - coverage: Coverage calculation utilities
#   - importTree: INTERNAL vendored dendritic auto-discovery helper.
#     Not re-exported from lib.*; used only by internal option-module
#     entry points to avoid a hand-maintained imports list. See
#     ./import-tree/LICENSE (Apache 2.0) for attribution.
{ lib }:
{
  mkFlake = import ./mkFlake.nix { inherit lib; };
  evalLibModules = import ./evalLibModules.nix { inherit lib; };
  mkAdapter = import ./mkAdapter.nix { inherit lib; };
  mkLib = import ./mkLib.nix { inherit lib; };
  mkSpecialArgsLib = import ./mkSpecialArgsLib.nix { inherit lib; };
  withLib = import ./withLib.nix { inherit lib; };
  backends = import ./backends.nix { inherit lib; };
  coverage = import ./coverage.nix { inherit lib; };
  importTree = import ./import-tree;
}
