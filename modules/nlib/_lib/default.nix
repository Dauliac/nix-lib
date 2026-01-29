# nlib - Nix library utilities
#
# Exports:
#   - mkAdapter: Factory to create adapters for any module system
#   - backends: Test backend adapters (nix-unit, nixt, nixtest, runTests)
#   - coverage: Coverage calculation utilities
{ lib }:
{
  mkAdapter = import ./mkAdapter.nix { inherit lib; };
  backends = import ./backends.nix { inherit lib; };
  coverage = import ./coverage.nix { inherit lib; };
}
