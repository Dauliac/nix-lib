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
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      flake = {
        # Expose the flake module for consumers
        flakeModules.default = ./modules/flake;

        # Expose lib for direct usage
        lib.nlib = import ./modules/lib { lib = inputs.nixpkgs.lib; };
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
