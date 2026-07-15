# Standalone test scenario (non-flake-parts)
#
# E2E tests for mkStandaloneLib - the API for non-flake-parts flakes.
# This flake intentionally does NOT use flake-parts to verify the standalone API works.
#
# Run with: nix run ./tests/scenarios/standalone#test
{
  description = "nix-lib standalone API tests (non-flake-parts)";

  inputs = {
    get-flake.url = "github:ursi/get-flake";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-unit.url = "github:nix-community/nix-unit";
  };

  outputs =
    {
      self,
      get-flake,
      nixpkgs,
      nix-unit,
      ...
    }:
    let
      nlib = get-flake ../../..;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Test: Basic standalone lib with self-reference
      basicLib = nlib.lib.nix-lib.mkStandaloneLib {
        inherit nixpkgs;
        namespace = "basic";

        libs = self: {
          double = {
            type = self.types.functionTo self.types.int;
            fn = x: x * 2;
            description = "Double a number";
            tests = {
              "doubles 5" = {
                args.x = 5;
                expected = 10;
              };
              "doubles 0" = {
                args.x = 0;
                expected = 0;
              };
              "doubles negative" = {
                args.x = -3;
                expected = -6;
              };
            };
          };

          # Self-reference test: quadruple uses double
          quadruple = {
            type = self.types.functionTo self.types.int;
            fn = x: self.fns.double (self.fns.double x);
            description = "Quadruple using double twice";
            tests."quadruples 3" = {
              args.x = 3;
              expected = 12;
            };
          };

          # Nested namespace test
          math.add = {
            type = self.types.functionTo self.types.int;
            fn = { a, b }: a + b;
            description = "Add two numbers";
            tests."adds 2 and 3" = {
              args.x = {
                a = 2;
                b = 3;
              };
              expected = 5;
            };
          };

          math.subtract = {
            type = self.types.functionTo self.types.int;
            fn = { a, b }: a - b;
            description = "Subtract two numbers";
            tests."subtracts 5 and 3" = {
              args.x = {
                a = 5;
                b = 3;
              };
              expected = 2;
            };
          };

          # Cross-namespace reference test
          math.doubleSum = {
            type = self.types.functionTo self.types.int;
            fn = { a, b }: self.fns.double (self.fns.math.add { inherit a b; });
            description = "Double the sum of two numbers";
            tests."doubles sum of 2 and 3" = {
              args.x = {
                a = 2;
                b = 3;
              };
              expected = 10;
            };
          };
        };
      };

      # Test: Multiple assertions format
      assertionsLib = nlib.lib.nix-lib.mkStandaloneLib {
        inherit nixpkgs;
        namespace = "assertions";

        libs = self: {
          abs = {
            type = self.types.functionTo self.types.int;
            fn = x: if x < 0 then -x else x;
            description = "Absolute value";
            tests."handles various inputs" = {
              args.x = -5;
              assertions = [
                {
                  name = "is positive";
                  check = r: r >= 0;
                }
                {
                  name = "equals 5";
                  expected = 5;
                }
              ];
            };
          };
        };
      };

      # Test: Visibility (private functions)
      visibilityLib = nlib.lib.nix-lib.mkStandaloneLib {
        inherit nixpkgs;
        namespace = "visibility";

        libs = self: {
          # Private helper (not exported)
          _helper = {
            type = self.types.functionTo self.types.int;
            fn = x: x + 1;
            description = "Internal helper";
            visible = false;
          };

          # Public function using private helper
          addTwo = {
            type = self.types.functionTo self.types.int;
            fn = x: self.fns._helper (self.fns._helper x);
            description = "Add two using internal helper";
            tests."adds 2 to 5" = {
              args.x = 5;
              expected = 7;
            };
          };
        };
      };

      # Merge all test libs
      allTests = basicLib.tests // assertionsLib.tests // visibilityLib.tests;

    in
    {
      # Expose libs for manual testing
      lib = basicLib.lib // assertionsLib.lib // visibilityLib.lib;

      # Combined tests for nix-unit
      tests = allTests;

      # Individual lib outputs for inspection
      _libs = {
        basic = basicLib;
        assertions = assertionsLib;
        visibility = visibilityLib;
      };

      # Test runner app
      apps.${system} =
        let
          testApp = {
            type = "app";
            program =
              pkgs.writeShellApplication {
                name = "test";
                runtimeInputs = [ nix-unit.packages.${system}.default ];
                text = ''
                  echo "=== Standalone API test scenario ==="
                  echo ""
                  echo "Testing mkStandaloneLib for non-flake-parts flakes"
                  echo ""

                  echo "=== Verifying lib structure ==="
                  echo "lib.basic.double exists: $(nix eval .#lib.basic.double --apply 'f: if f != null then "yes" else "no"')"
                  echo "lib.basic.quadruple exists: $(nix eval .#lib.basic.quadruple --apply 'f: if f != null then "yes" else "no"')"
                  echo "lib.basic.math.add exists: $(nix eval .#lib.basic.math.add --apply 'f: if f != null then "yes" else "no"')"
                  echo "lib.basic.math.doubleSum exists: $(nix eval .#lib.basic.math.doubleSum --apply 'f: if f != null then "yes" else "no"')"
                  echo ""

                  echo "=== Verifying self-reference works ==="
                  echo "double 5 = $(nix eval .#lib.basic.double --apply 'f: f 5')"
                  echo "quadruple 3 = $(nix eval .#lib.basic.quadruple --apply 'f: f 3')"
                  echo "math.doubleSum {a=2;b=3} = $(nix eval .#lib.basic.math.doubleSum --apply 'f: f {a=2;b=3;}')"
                  echo ""

                  echo "=== Verifying visibility (private helpers) ==="
                  echo "_helper should NOT be in lib.visibility:"
                  nix eval .#lib.visibility --apply 'builtins.attrNames' || true
                  echo ""

                  echo "=== Running nix-unit tests ==="
                  nix-unit --flake .#tests
                  echo ""

                  echo "=== All standalone API tests passed! ==="
                '';
              }
              + "/bin/test";
          };
        in
        {
          test = testApp;
          default = testApp;
        };

      # Dev shell for debugging
      devShells.${system}.default = pkgs.mkShell {
        packages = [ nix-unit.packages.${system}.default ];
        shellHook = ''
          echo "Standalone API test scenario"
          echo "Run tests: nix run .#test"
          echo ""
          echo "Manual testing:"
          echo "  nix eval .#lib.basic.double --apply 'f: f 5'"
          echo "  nix eval .#lib.basic.quadruple --apply 'f: f 3'"
          echo "  nix eval .#lib.basic.math.add --apply 'f: f {a=2;b=3;}'"
        '';
      };
    };
}
