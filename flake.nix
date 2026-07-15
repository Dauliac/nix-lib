{
  description = "nix-lib - Nix library module with tested, typed, documented functions";

  # Top-level outputs (mkAdapter, mkLib, etc.) are pure functions that only
  # need nixpkgs.lib — no pkgs instantiation required. Consumers can use them
  # directly (e.g., nix-lib.mkAdapter { name = "nixos"; }) without importing
  # any flake-parts modules.
  outputs =
    inputs:
    let
      lib = inputs.nixpkgs-lib.lib;
      nlibLib = import ./modules/nix-lib/_lib { inherit lib; };
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./modules/nix-lib/_pure.nix
        ./modules/nix-lib-outputs.nix
        ./modules/systems.nix
        ./modules/partitions.nix
      ];
    }
    // {
      inherit (nlibLib)
        mkFlake
        evalLibModules
        mkSpecialArgsLib
        mkLib
        mkAdapter
        withLib
        ;
    };

  inputs = {
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
      url = "github:hercules-ci/flake-parts";
    };
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
  };

}
