# nlib - Nix library utilities
#
# Exports:
#   - mkLib: Create tested, typed, documented library functions
#   - mkLibFromFile: Import lib file with name derived from filename
#   - backends: Test backend adapters (nix-unit, nixt, nixtest, runTests)
#   - coverage: Coverage calculation utilities
{ lib }:
{
  mkLib = import ./mkLib.nix { inherit lib; };
  mkLibFromFile = import ./mkLibFromFile.nix { inherit lib; };
  backends = import ./backends.nix { inherit lib; };
  coverage = import ./coverage.nix { inherit lib; };
}
