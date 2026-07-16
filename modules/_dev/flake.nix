# Dev-only inputs — NOT fetched by consumers.
# Provides nixpkgs, dev tools, and test-required module system inputs.
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-unit = {
      url = "github:nix-community/nix-unit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-tests = {
      url = "github:danielefongo/nix-tests";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixtest.url = "github:jetify-com/nixtest";
    namaka = {
      url = "github:nix-community/namaka";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixt = {
      url = "github:nix-community/nixt";
    };
    # Test-required: the BDD tests + examples need these to create
    # nixosConfigurations, homeConfigurations, etc.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = _: { };
}
