# mkLibOptionFromFileName - mkLibOption with name derived from filename
#
# This is a curried function:
#   1. First call with path (done by wrapLibModule)
#   2. Returns function used in the lib file (without name argument)
#
# Usage in lib file (e.g., libs/double.nix):
#   { lib, mkLibOptionFromFileName, ... }:
#   mkLibOptionFromFileName {
#     # name = "double" (auto-derived from filename)
#     type = lib.types.functionTo lib.types.int;
#     fn = x: x * 2;  # Top-level fn, used by tests
#     description = "Double the input";
#     tests."doubles 5" = {
#       args.x = 5;
#       expected = 10;
#     };
#   }
{ lib }:
let
  mkLibOption = import ./mkLibOption.nix { inherit lib; };
  pathToName = path: lib.removeSuffix ".nix" (builtins.baseNameOf (toString path));
in
# Called by module wrapper with file path
path:
# Returns function for use in lib file
args:
let
  name = pathToName path;
in
mkLibOption (args // { inherit name; })
