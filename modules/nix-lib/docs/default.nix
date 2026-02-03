# nix-lib.docs - Documentation generation feature
#
# Generates markdown documentation for all defined libs.
#
# Usage:
#   nix build .#nix-lib-docs
#
{ ... }:
{
  imports = [
    ./package.nix
    ./enableOutput.nix
  ];
}
