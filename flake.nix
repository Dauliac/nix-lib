{
  description = "nix-lib - Nix library module with tested, typed, documented functions";

  # Public API is at lib.* (e.g., nlib.lib.mkFlake, nlib.lib.mkAdapter).
  # These are pure functions that only need nixpkgs.lib — no pkgs instantiation
  # required. Consumers use them directly without importing flake-parts modules.
  outputs =
    inputs:
    let
      lib = inputs.nixpkgs-lib.lib;
      nlibLib = import ./modules/nix-lib/_lib { inherit lib; };
      result = inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [
          ./modules/nix-lib-outputs.nix
          ./modules/systems.nix
          ./modules/partitions.nix
        ];
      };
    in
    result
    // {
      lib = (result.lib or { }) // {
        inherit (nlibLib)
          mkFlake
          evalLibModules
          mkSpecialArgsLib
          mkLib
          mkAdapter
          withLib
          ;
      };
    };

  inputs = {
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
      url = "github:hercules-ci/flake-parts";
    };
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
  };

}
