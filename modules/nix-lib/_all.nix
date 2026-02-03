# nix-lib - all option modules
#
# Explicit imports for mkAdapter (NixOS/home-manager/etc.)
# This file is ignored by import-tree due to the _ prefix.
{ ... }:
{
  imports = [
    ./enable.nix
    ./namespace.nix
    ./testing/backend.nix
    ./testing/reporter.nix
    ./testing/outputPath.nix
    ./coverage.nix
    ./lib/internal.nix
  ];
}
