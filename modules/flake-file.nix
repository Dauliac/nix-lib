# flake-file configuration for auto-generating flake.nix
{ inputs, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.dendritic
  ];

  flake-file.description = "nlib - Nix library module with tested, typed, documented functions";

  flake-file.inputs.nix-unit = {
    url = "github:nix-community/nix-unit";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake-file.inputs.treefmt-nix = {
    url = "github:numtide/treefmt-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
