# nix-lib flake outputs (flakeModules, nixosModules, lib.nix-lib.mkAdapter)
#
# Note: mkStandaloneLib is exported via lib.nix-lib.mkStandaloneLib
# (defined in lib/flake.nix which exports nixLibLib as lib.nix-lib)
{ inputs, ... }:
let
  nixLibLib = import ./nix-lib/_lib { inherit (inputs.nixpkgs) lib; };
in
{
  # Consumers import this module via flake-parts
  flake.flakeModules.default = import ./nix-lib/_default.nix;

  # Pure module — no pkgs, no docs, no per-system support.
  # For consumers who only need pure Nix lib wiring (issue #7).
  flake.flakeModules.pure = import ./nix-lib/_pure.nix;

  # NixOS/home-manager modules for consumers
  # All adapters automatically merge libs into config.lib
  flake.nixosModules.default = nixLibLib.mkAdapter { name = "nixos"; };
  flake.homeModules.default = nixLibLib.mkAdapter { name = "home-manager"; };
  flake.darwinModules.default = nixLibLib.mkAdapter { name = "nix-darwin"; };
  flake.nixvimModules.default = nixLibLib.mkAdapter { name = "nixvim"; };
  flake.systemManagerModules.default = nixLibLib.mkAdapter { name = "system-manager"; };

  # Wrappers adapter - shared namespace for:
  # - nix-wrapper-modules (github:viperML/nix-wrapper-modules)
  # - Lassulus wrappers (github:Lassulus/wrappers)
  # Use with: imports = [ nix-lib.wrapperModules.default ];
  flake.wrapperModules.default = nixLibLib.mkAdapter { name = "wrappers"; };
}
