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

        # Expose tests for nix-unit
        tests = import ./tests { pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux; };
      };

      perSystem =
        { pkgs, inputs', ... }:
        {
          # Formatter
          formatter = pkgs.nixfmt-rfc-style;

          # Development shell
          devShells.default = pkgs.mkShell {
            packages = [
              inputs'.nix-unit.packages.default
              pkgs.nixfmt-rfc-style
            ];
          };

          # Run nlib's own tests
          checks.nlib-tests = pkgs.runCommand "nlib-tests" { } ''
            ${inputs'.nix-unit.packages.default}/bin/nix-unit \
              --flake ${self}#tests
            touch $out
          '';
        };
    };
}
