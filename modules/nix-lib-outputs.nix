# nix-lib flake outputs (flakeModules, nixosModules, lib.nix-lib.mkAdapter)
{ inputs, ... }:
let
  nixLibLib = import ./nix-lib/_lib { inherit (inputs.nixpkgs) lib; };
in
{
  # Consumers import this module via flake-parts
  flake.flakeModules.default = inputs.import-tree ./nix-lib;

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
