# nlib flake outputs (flakeModules, nixosModules, lib.nlib.mkAdapter)
{ inputs, ... }:
let
  nlibLib = import ./nlib/_lib { inherit (inputs.nixpkgs) lib; };
in
{
  # Consumers import this module via flake-parts
  flake.flakeModules.default = inputs.import-tree ./nlib;

  # NixOS/home-manager modules for consumers
  # All adapters automatically merge libs into config.lib
  flake.nixosModules.default = nlibLib.mkAdapter { name = "nixos"; };
  flake.homeModules.default = nlibLib.mkAdapter { name = "home-manager"; };
  flake.darwinModules.default = nlibLib.mkAdapter { name = "nix-darwin"; };
  flake.nixvimModules.default = nlibLib.mkAdapter { name = "nixvim"; };
  flake.systemManagerModules.default = nlibLib.mkAdapter { name = "system-manager"; };

  # Wrappers adapter - shared namespace for:
  # - nix-wrapper-modules (github:viperML/nix-wrapper-modules)
  # - Lassulus wrappers (github:Lassulus/wrappers)
  # Use with: imports = [ nlib.wrapperModules.default ];
  flake.wrapperModules.default = nlibLib.mkAdapter { name = "wrappers"; };
}
