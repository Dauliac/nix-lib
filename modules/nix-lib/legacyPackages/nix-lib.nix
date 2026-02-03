# legacyPackages.nix-lib (perSystem)
#
# Note: This export is handled by lib/perSystem.nix
# which sets legacyPackages.nix-lib = perSystemFns
#
# This file exists for organizational consistency but doesn't
# define additional functionality. The actual export is in lib/perSystem.nix.
#
_: {
  # Export is handled by lib/perSystem.nix:
  #   config.legacyPackages.nix-lib = perSystemFns;
}
