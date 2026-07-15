# mkFlake standalone example (no flake-parts)
#
# This example shows how to use nlib.lib.mkFlake without flake-parts.
# Lib modules are evaluated and lib.* is directly available in outputs.
#
# Usage:
#   nix eval -f examples/mkFlake-standalone.nix lib.math.double --apply 'f: f 5'
#
let
  # Mock inputs for example (in real flake, these come from inputs)
  nixpkgs = builtins.getFlake "github:nixos/nixpkgs/nixpkgs-unstable";
  nlib = builtins.getFlake (toString ./..);
in
nlib.lib.mkFlake
  {
    inputs = { inherit nixpkgs nlib; };
    modules = [
      # Inline lib module
      (
        { lib, ... }:
        {
          lib.math.double = {
            fn = x: x * 2;
            description = "Double a number";
            tests."doubles 5" = {
              args.x = 5;
              expected = 10;
            };
          };

          lib.math.triple = {
            fn = x: x * 3;
            description = "Triple a number";
          };
        }
      )
    ];
  }
  {
    # Direct flake outputs
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.writeText "example" "Hello from mkFlake standalone!";
  }
