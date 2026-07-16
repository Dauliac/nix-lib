# mkFlake with flake-parts example
#
# This example shows how to use nlib.lib.mkFlake with flake-parts integration.
# Libs are available in the `lib` argument during OPTIONS phase!
#
# Usage in a real flake.nix:
#
#   {
#     inputs = {
#       nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
#       flake-parts.url = "github:hercules-ci/flake-parts";
#       nlib.url = "github:Dauliac/nlib";
#     };
#
#     outputs = inputs:
#       inputs.nlib.lib.mkFlake {
#         inherit inputs;
#         modules = [
#           ./libs/math.nix
#           ./libs/string.nix
#         ];
#         flake-parts = inputs.flake-parts;
#       } {
#         systems = [ "x86_64-linux" "aarch64-linux" ];
#
#         perSystem = { lib, pkgs, ... }: {
#           # lib.math.double is available HERE in options phase!
#           packages.default = pkgs.writeText "result"
#             "double 5 = ${toString (lib.math.double 5)}";
#         };
#       };
#   }
#
# Example lib module (libs/math.nix):
#
#   { lib, config, ... }: {
#     lib.math.double = {
#       fn = x: x * 2;
#       description = "Double a number";
#       tests."doubles 5" = { args.x = 5; expected = 10; };
#     };
#
#     # Self-referencing: quadruple uses double
#     lib.math.quadruple = {
#       fn = x: config.lib.math.double.fn (config.lib.math.double.fn x);
#       description = "Quadruple a number";
#     };
#   }
#
"See the comments above for usage examples. This file is documentation only."
