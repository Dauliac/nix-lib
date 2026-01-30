# nlib flake outputs (flakeModules, nixosModules, lib.nlib.mkAdapter)
{ inputs, ... }:
let
  nlibLib = import ./nlib/_lib { inherit (inputs.nixpkgs) lib; };
  libShorthand = ./nlib/_lib/libShorthand.nix;
in
{
  # Consumers import this module via flake-parts
  flake.flakeModules.default = inputs.import-tree ./nlib;

  # NixOS/home-manager modules for consumers
  flake.nixosModules.default = nlibLib.mkAdapter { name = "nixos"; };
  flake.homeModules.default = nlibLib.mkAdapter { name = "home-manager"; };
  flake.darwinModules.default = nlibLib.mkAdapter { name = "nix-darwin"; };
  flake.nixvimModules.default = nlibLib.mkAdapter { name = "nixvim"; };
  flake.systemManagerModules.default = nlibLib.mkAdapter { name = "system-manager"; };

  # Optional: config.lib shorthand (for systems without built-in options.lib)
  # Usage: imports = [ nlib.nixosModules.default nlib.nixosModules.libShorthand ];
  # Then: config.lib.myFunc instead of config.nlib.fns.myFunc
  # Note: Do NOT use with home-manager (it has its own options.lib)
  flake.nixosModules.libShorthand = libShorthand;
  flake.darwinModules.libShorthand = libShorthand;
  flake.nixvimModules.libShorthand = libShorthand;
  flake.systemManagerModules.libShorthand = libShorthand;
}
