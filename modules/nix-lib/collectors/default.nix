# nix-lib.collectors - Collector feature
#
# Collectors aggregate libs from different module systems (NixOS, home-manager, etc.)
# into the flake output.
#
{ ... }:
{
  imports = [
    ./collectorDefs.nix
    ./systemCollectors.nix
    ./metaCollectors.nix
  ];
}
