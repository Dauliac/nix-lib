{
  description = "nlib - Nix library module with tested, typed, documented functions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    nix-unit = {
      url = "github:nix-community/nix-unit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    let
      lib = inputs.nixpkgs.lib;
      nlibLib = import ./modules/lib { inherit lib; };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      flake = {
        # flake-parts module
        flakeModules.default = ./modules/flake;

        # Convenience modules for common module systems
        nixosModules.default = nlibLib.mkAdapter { name = "nixos"; };
        homeModules.default = nlibLib.mkAdapter { name = "home-manager"; };
        nixvimModules.default = nlibLib.mkAdapter { name = "nixvim"; };
        darwinModules.default = nlibLib.mkAdapter { name = "nix-darwin"; };

        # Generic adapter factory for any module system
        mkAdapter = nlibLib.mkAdapter;

        # Expose lib for direct usage
        lib.nlib = nlibLib;
      };

      perSystem =
        { pkgs, system, ... }:
        {
          # Formatter
          formatter = pkgs.nixfmt;

          # Tests for nix-unit (attrset, not derivation)
          # Run via: nix-unit --flake .#legacyPackages.<system>.tests
          legacyPackages.tests = import ./tests { inherit pkgs; };

          # Development shell
          devShells.default = pkgs.mkShell {
            packages = [
              inputs.nix-unit.packages.${system}.default
              pkgs.nixfmt
            ];
            shellHook = ''
              echo "Run tests: nix-unit --flake .#legacyPackages.${system}.tests"
            '';
          };
        };
    };
}
