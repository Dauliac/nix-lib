# nix-lib legacyPackages - Legacy packages exports
#
# Exports libs to legacyPackages.<sys>.lib.<ns>.<name>
# and legacyPackages.<sys>.nix-lib.<name>
#
{ ... }:
{
  imports = [
    ./lib.nix
    ./nix-lib.nix
  ];
}
