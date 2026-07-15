# nix-lib flake outputs (flakeModules, nixosModules, etc.)
#
# Public API (lib.*) is set via merge in flake.nix, not here,
# because the dev partition also imports lib/flake.nix which sets flake.lib.
{ inputs, ... }:
let
  nixLibLib = import ./nix-lib/_lib { inherit (inputs.nixpkgs-lib) lib; };
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
