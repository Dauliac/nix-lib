# nix-unit test scenario
#
# E2E tests using nix-unit backend.
# Run with: nix run ./tests/scenarios/nix-unit#test
{
  description = "nix-lib e2e tests with nix-unit backend";

  inputs = {
    get-flake.url = "github:ursi/get-flake";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nixvim.url = "github:nix-community/nixvim";
    nix-darwin.url = "github:LnL7/nix-darwin";
    system-manager.url = "github:numtide/system-manager";
    devour-flake = {
      url = "github:srid/devour-flake";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      nix-lib = inputs.get-flake ../../..;
      inherit (nix-lib.inputs) nix-unit;
    in
    nix-lib.inputs.flake-parts.lib.mkFlake
      {
        inputs = inputs // {
          inherit nix-lib;
        };
      }
      (
        { ... }:
        {
          systems = [ "x86_64-linux" ];

          imports = [
            nix-lib.flakeModules.default
            nix-unit.modules.flake.default
            # Example integrations
            ../../../examples/full-integration.nix
            # BDD test modules (shared)
            ../../bdd/collectors.nix
            ../../bdd/adapters.nix
            ../../bdd/libDef.nix
          ];

          # Use nix-unit backend
          nix-lib.testing = {
            backend = "nix-unit";
            reporter = "junit";
            outputPath = "test-results.xml";
          };

          perSystem =
            {
              pkgs,
              system,
              lib,
              ...
            }:
            let
              devour-flake = pkgs.callPackage inputs.devour-flake { };
            in
            {
              nix-unit.inputs = inputs // {
                inherit nix-lib;
              };

              # Disable automatic nix-unit check (sandbox incompatibility with get-flake)
              checks.nix-unit = lib.mkForce (pkgs.runCommand "nix-unit-skip" { } "mkdir -p $out");

              apps.test = {
                type = "app";
                program =
                  pkgs.writeShellApplication {
                    name = "test";
                    runtimeInputs = [
                      nix-unit.packages.${system}.default
                      devour-flake
                    ];
                    text = ''
                      echo "=== nix-unit test scenario ==="
                      echo ""
                      echo "=== Running nix-unit tests ==="
                      nix-unit --flake .#tests
                      echo ""
                      echo "=== Building all flake outputs with devour-flake ==="
                      devour-flake ../../..
                      echo ""
                      echo "=== All nix-unit tests passed! ==="
                    '';
                  }
                  + "/bin/test";
              };

              devShells.default = pkgs.mkShell {
                packages = [
                  nix-unit.packages.${system}.default
                  devour-flake
                ];
                shellHook = ''
                  echo "nix-unit test scenario"
                  echo "Run tests: nix run .#test"
                '';
              };
            };
        }
      );
}
