# Full nix-lib module — all features including docs and per-system libs.
{ ... }:
{
  imports = [
    ./_all.nix
    ./adapterDefs
    ./collectors/collectorDefs.nix
    ./collectors/metaCollectors.nix
    ./collectors/systemCollectors.nix
    ./lib/flake.nix
    ./lib/perSystem.nix
    ./tests/flake.nix
    ./legacyPackages/lib.nix
    ./legacyPackages/nix-lib.nix
    ./docs/enableOutput.nix
    ./docs/package.nix
  ];
}
