{
  description = "Test mkFlake with flake-parts integration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    get-flake.url = "github:ursi/get-flake";
  };

  outputs =
    inputs:
    let
      nlib = inputs.get-flake ../../..;
    in
    nlib.lib.mkFlake
      {
        inputs = inputs // {
          inherit nlib;
        };
        modules = [
          ./libs/math.nix
        ];
        flake-parts = inputs.flake-parts;
      }
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        perSystem =
          {
            lib,
            pkgs,
            system,
            ...
          }:
          {
            # lib.math.* should be available in options phase!
            packages.default = pkgs.writeText "test-result" "double 5 = ${toString (lib.math.double 5)}, quadruple 3 = ${toString (lib.math.quadruple 3)}";

            # Test runner
            apps.test =
              let
                testScript = pkgs.writeShellApplication {
                  name = "test-mkFlake-flake-parts";
                  text = ''
                    echo "=== mkFlake flake-parts test ==="
                    echo ""
                    echo "Testing lib injection in options phase..."
                    result=$(cat ${pkgs.writeText "test-result" "double 5 = ${toString (lib.math.double 5)}, quadruple 3 = ${toString (lib.math.quadruple 3)}"})
                    expected="double 5 = 10, quadruple 3 = 12"
                    if [ "$result" = "$expected" ]; then
                      echo "✓ Options phase lib injection works!"
                      echo "  Result: $result"
                    else
                      echo "✗ Options phase lib injection failed!"
                      echo "  Expected: $expected"
                      echo "  Got: $result"
                      exit 1
                    fi
                    echo ""
                    echo "=== All mkFlake flake-parts tests passed! ==="
                  '';
                };
              in
              {
                type = "app";
                program = "${testScript}/bin/test-mkFlake-flake-parts";
              };

            apps.default = {
              type = "app";
              program = "${
                pkgs.writeShellApplication {
                  name = "test";
                  text = "nix run .#test";
                }
              }/bin/test";
            };
          };
      };
}
