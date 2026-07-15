# Pure nix-lib module — zero pkgs dependency.
#
# Use nix-lib.flakeModules.pure instead of .default when you only need
# pure Nix lib definitions without pkgs, docs, or per-system support.
#
# What's included:
#   - nix-lib.lib.* definitions (flake-level)
#   - Adapter definitions (NixOS, home-manager, etc.)
#   - Collectors and test generation
#   - Linter metadata
#
# What's excluded:
#   - Per-system lib definitions (nix-lib.lib.* in perSystem — needs pkgs)
#   - Documentation package (nix-lib.docs.* — needs pkgs)
#
# Usage:
#   imports = [ nix-lib.flakeModules.pure ];
#
{ ... }:
{
  imports = [
    ./_all.nix
    ./adapterDefs
    ./collectors/collectorDefs.nix
    ./collectors/metaCollectors.nix
    ./collectors/systemCollectors.nix
    ./lib/flake.nix
    ./linter.nix
    ./tests/flake.nix
    ./legacyPackages/lib.nix
    ./legacyPackages/nix-lib.nix
  ];
}
