# mkLibFromFile - Import a lib file with name derived from filename
#
# Injects `name` (extracted from filename) into the imported module.
# The lib file should use `inherit name;` when calling mkLib.
#
# Usage:
#   mkLibFromFile ./examples/add.nix { }
#   # Returns mkLib result with name="add"
{ lib }:
let
  mkLib = import ./mkLib.nix { inherit lib; };

  # Extract name from path: "./foo/bar.nix" -> "bar"
  pathToName = path: lib.removeSuffix ".nix" (builtins.baseNameOf (toString path));
in
path: extraArgs:
let
  name = pathToName path;
in
import path (extraArgs // { inherit lib mkLib name; })
