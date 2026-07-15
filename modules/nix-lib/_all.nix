# nix-lib - all option modules
#
# Explicit imports for mkAdapter (NixOS/home-manager/etc.)
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
