# nix-lib.lib - Library definition feature
#
# Provides the nix-lib.lib.<name> API for defining libs at both
# flake-level and perSystem-level.
#
{ ... }:
{
  imports = [
    ./flake.nix
    ./perSystem.nix
    ./_internal.nix
  ];
}
