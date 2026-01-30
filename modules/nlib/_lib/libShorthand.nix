# Optional module to expose nlib.fns at config.lib
#
# This merges nlib functions into the existing config.lib (from NixOS/home-manager).
#
# Usage:
#   imports = [ nlib.nixosModules.default nlib.nixosModules.libShorthand ];
#
# Then use: config.lib.myFunc instead of config.nlib.fns.myFunc
#
{ config, lib, ... }:
{
  # Don't declare options.lib - it already exists in NixOS/home-manager
  # Just merge our functions into the existing config.lib
  config.lib = config.nlib.fns;
}
