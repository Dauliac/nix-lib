{
  description = "nix-lib tests - unit tests and integration tests";

  inputs = {
    get-flake.url = "github:ursi/get-flake";
    # nixpkgs is required by flake-parts for perSystem.pkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nixvim.url = "github:nix-community/nixvim";
    nix-darwin.url = "github:LnL7/nix-darwin";
    system-manager.url = "github:numtide/system-manager";
  };

  outputs =
    inputs:
    let
      nix-lib = inputs.get-flake ../.;
      inherit (nix-lib.inputs) nix-unit;
    in
    nix-lib.inputs.flake-parts.lib.mkFlake
      {
        # Pass self as THIS flake (tests flake)
        inputs = inputs // {
          inherit nix-lib;
        };
      }
      (
        { ... }:
        {
          systems = [ "x86_64-linux" ];

          imports = [
            # nix-lib flake module
            nix-lib.flakeModules.default
            # nix-unit module for perSystem.nix-unit.tests support
            # Note: The automated nix-unit check in `nix flake check` may fail due to
            # get-flake sandbox issues, but manual execution works:
            #   nix-unit --flake ./tests#tests
            nix-unit.modules.flake.default
            # Example integrations
            ../examples/full-integration.nix
            # BDD test modules
            ./bdd/collectors.nix
            ./bdd/adapters.nix
            ./bdd/libDef.nix
          ];

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
            {
              # nix-unit configuration for perSystem.nix-unit.tests
              nix-unit.inputs = nix-unit.inputs // inputs // { inherit nix-lib; };

              # Disable automatic nix-unit check (can't work in sandbox due to get-flake)
              checks.nix-unit = lib.mkForce (pkgs.runCommand "nix-unit-skip" { } "mkdir -p $out");

              apps.test = {
                type = "app";
                program =
                  pkgs.writeShellApplication {
                    name = "test";
                    runtimeInputs = [ nix-unit.packages.${system}.default ];
                    text = ''
                      echo "=== Running nix-unit tests ==="
                      nix-unit --flake .#tests
                      echo ""
                      echo "=== All tests passed! ==="
                    '';
                  }
                  + "/bin/test";
              };

              devShells.default = pkgs.mkShell {
                packages = [
                  nix-unit.packages.${system}.default
                ];
                shellHook = ''
                  echo "Run tests: nix run .#test"
                '';
              };
            };
        }
      );
}
