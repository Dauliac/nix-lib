{
  description = "nlib tests - unit tests and integration tests";

  inputs = {
    get-flake.url = "github:ursi/get-flake";
    home-manager.url = "github:nix-community/home-manager";
    nixvim.url = "github:nix-community/nixvim";
    nix-darwin.url = "github:LnL7/nix-darwin";
    system-manager.url = "github:numtide/system-manager";
  };

  outputs =
    inputs:
    let
      nlib = inputs.get-flake ../.;
      inherit (nlib.inputs) nixpkgs nix-unit;
    in
    nlib.inputs.flake-parts.lib.mkFlake
      {
        inputs = inputs // {
          self = nlib;
          inherit nixpkgs;
        };
      }
      (
        { config, ... }:
        let
          # Build-time lib evaluation check - creates a derivation that evaluates libs
          # If any lib fails to evaluate, the build fails
          mkLibCheck =
            pkgs: name: libAttr:
            pkgs.runCommand "check-lib-${name}" { } ''
              echo "Evaluating lib.${name}..."
              echo "Found attributes: ${builtins.toJSON (builtins.attrNames libAttr)}"
              mkdir -p $out
              echo '${builtins.toJSON (builtins.attrNames libAttr)}' > $out/${name}.json
            '';

          # Access the flake-level lib
          flakeLib = config.flake.lib;
        in
        {
          systems = [ "x86_64-linux" ];

          imports = [
            nlib.flakeModules.default
            ../examples/full-integration.nix
          ];

          nlib.testing = {
            backend = "nix-unit";
            reporter = "junit";
            outputPath = "test-results.xml";
          };

          perSystem =
            { system, ... }:
            let
              pkgs = nixpkgs.legacyPackages.${system};

              # Pure Nix assertions for tests - runs at evaluation time
              # If any test fails, evaluation fails and build aborts
              testResults = builtins.mapAttrs (
                name: test:
                let
                  passed = test.expr == test.expected;
                in
                if passed then
                  "✅ ${name}"
                else
                  throw "❌ ${name}: expected ${builtins.toJSON test.expected}, got ${builtins.toJSON test.expr}"
              ) config.flake.tests.lib;

              # Derivation that records test results (tests run at eval time)
              unitTestsCheck = pkgs.runCommand "nix-unit-tests" { } ''
                mkdir -p $out
                echo "Test results:" > $out/results.txt
                ${pkgs.lib.concatStringsSep "\n" (
                  builtins.map (name: ''echo "${testResults.${name}}" >> $out/results.txt'') (
                    builtins.attrNames testResults
                  )
                )}
                echo "" >> $out/results.txt
                echo "🎉 ${toString (builtins.length (builtins.attrNames testResults))} tests passed" >> $out/results.txt
                cat $out/results.txt
              '';
            in
            {
              # Checks that evaluate all lib namespaces at build time
              checks = {
                lib-root = mkLibCheck pkgs "root" flakeLib;
                lib-flake = mkLibCheck pkgs "flake" flakeLib.flake;
                lib-nixos = mkLibCheck pkgs "nixos" flakeLib.nixos;
                lib-home = mkLibCheck pkgs "home" flakeLib.home;
                lib-darwin = mkLibCheck pkgs "darwin" flakeLib.darwin;
                lib-vim = mkLibCheck pkgs "vim" flakeLib.vim;
                lib-system = mkLibCheck pkgs "system" flakeLib.system;
                lib-wrappers = mkLibCheck pkgs "wrappers" flakeLib.wrappers;
                unit-tests = unitTestsCheck;
              };

              apps.build-all = {
                type = "app";
                program =
                  pkgs.writeShellApplication {
                    name = "build-all";
                    runtimeInputs = [ pkgs.nix ];
                    text = ''
                      set -euo pipefail
                      echo "=== Running all checks ==="
                      nix flake check .
                      echo ""
                      echo "=== All checks passed! ==="
                    '';
                  }
                  + "/bin/build-all";
              };

              devShells.default = pkgs.mkShell {
                packages = [
                  nix-unit.packages.${system}.default
                ];
                shellHook = ''
                  echo "Run checks: nix flake check"
                  echo "Run all:    nix run .#build-all"
                '';
              };
            };
        }
      );
}
