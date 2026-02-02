# flake-file configuration for auto-generating flake.nix
{ inputs, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.dendritic
  ];

  flake-file = {
    description = "nlib - Nix library module with tested, typed, documented functions";
    inputs = {
      nix-unit = {
        url = "github:nix-community/nix-unit";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-parts.follows = "flake-parts";
      };

      treefmt-nix = {
        url = "github:numtide/treefmt-nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      devour-flake = {
        url = "github:srid/devour-flake";
        flake = false;
      };
      get-flake.url = "github:ursi/get-flake";
    };
  };
}
