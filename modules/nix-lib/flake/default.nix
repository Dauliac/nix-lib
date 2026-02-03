# nix-lib flake.parts module
#
# Entry point for nix-lib flake-parts integration.
# Imports all feature modules.
#
# Output structure:
#   - flake.lib.flake.<name> for pure flake libs (no pkgs dependency)
#   - flake.lib.nix-lib for internal utilities
#   - flake.lib.<namespace>.<name> for collected libs
#   - legacyPackages.<sys>.lib.<ns>.<name> for system-specific libs
#   - flake.tests for nix-unit test cases
#   - packages.nix-lib-docs for documentation
#
{ ... }:
{
  imports = [
    ../lib
    ../collectors
    ../legacyPackages
    ../docs
    ../tests
    # Note: adapterDefs is imported by import-tree at the nix-lib level
  ];
}
