# mkFlake - Create flakes with lib modules
#
# Evaluates lib modules and produces flake outputs.
# Optionally integrates with flake-parts for full features.
#
# Usage (standalone):
#   nlib.mkFlake {
#     inherit inputs;
#     modules = [ ./libs ];
#   } {
#     packages.x86_64-linux.default = pkgs.hello;
#   }
#
# Usage (with flake-parts):
#   nlib.mkFlake {
#     inherit inputs;
#     modules = [ ./libs ];
#     flake-parts = inputs.flake-parts;
#   } {
#     perSystem = { lib, ... }: {
#       # lib.math.* available in options phase!
#     };
#   }
#
{ lib }:
{
  # Flake inputs (required)
  inputs,
  # Lib modules to evaluate
  modules ? [ ],
  # Optional: flake-parts input for integration
  flake-parts ? null,
}:
# Second argument: outputs or flake-parts modules
outputsOrModules:
let
  evalLibModules = import ./evalLibModules.nix { inherit lib; };

  # Evaluate lib modules
  evaluated = evalLibModules {
    inherit modules;
  };

  # Extend nixpkgs lib with evaluated libs
  extendedLib = lib.extend (final: prev: evaluated.fns);

  # Base lib outputs (always present)
  libOutputs = {
    lib = evaluated.fns;
    tests = evaluated.tests;
    # Expose lib modules for consumers
    libModules.default = modules;
  };

  # Check if flake-parts is provided
  hasFlakeParts = flake-parts != null;

in
if hasFlakeParts then
  # Flake-parts mode: wrap flake-parts.lib.mkFlake
  let
    flakePartsResult =
      flake-parts.lib.mkFlake
        {
          inherit inputs;
          specialArgs = {
            lib = extendedLib;
          };
        }
        {
          imports = [
            # User's flake-parts configuration as a module
            outputsOrModules
          ];
        };
  in
  # Merge flake-parts outputs with lib outputs
  flakePartsResult // libOutputs
else
  # Standalone mode: just merge outputs
  let
    # If outputsOrModules is a function, call it with extended lib
    resolvedOutputs =
      if builtins.isFunction outputsOrModules then
        outputsOrModules { lib = extendedLib; }
      else
        outputsOrModules;
  in
  libOutputs // resolvedOutputs
