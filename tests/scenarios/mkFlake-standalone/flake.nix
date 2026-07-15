{
  description = "Test mkFlake standalone mode (no flake-parts)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    get-flake.url = "github:ursi/get-flake";
  };

  outputs =
    inputs:
    let
      nlib = inputs.get-flake ../../..;
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs.legacyPackages.${system};

      flakeOutputs =
        nlib.lib.mkFlake
          {
            inputs = inputs // {
              inherit nlib;
            };
            modules = [
              ./libs/math.nix
            ];
          }
          {
            packages.${system}.default = pkgs.writeText "test" "double 5 = 10";
          };

      # Verify lib functions work at eval time
      doubleResult = flakeOutputs.lib.math.double 5;
      tripleResult = flakeOutputs.lib.math.triple 3;
    in
    let
      testApp = {
        type = "app";
        program =
          pkgs.writeShellApplication {
            name = "test-mkFlake-standalone";
            text = ''
              echo "=== mkFlake standalone test ==="
              echo ""
              echo "Testing lib.math.double..."
              result="${toString doubleResult}"
              if [ "$result" = "10" ]; then
                echo "✓ lib.math.double 5 = $result"
              else
                echo "✗ lib.math.double 5 = $result (expected 10)"
                exit 1
              fi
              echo ""
              echo "Testing lib.math.triple..."
              result="${toString tripleResult}"
              if [ "$result" = "9" ]; then
                echo "✓ lib.math.triple 3 = $result"
              else
                echo "✗ lib.math.triple 3 = $result (expected 9)"
                exit 1
              fi
              echo ""
              echo "=== All mkFlake standalone tests passed! ==="
            '';
          }
          + "/bin/test-mkFlake-standalone";
      };
    in
    flakeOutputs
    // {
      apps.${system} = {
        test = testApp;
        default = testApp;
      };
    };
}
