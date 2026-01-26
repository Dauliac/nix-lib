# mkLibOptionFromFileName - mkLibOption with name derived from filename
#
# This is a curried function:
#   1. First call with path (done by module wrapper)
#   2. Returns function used in the lib file (without name argument)
#
# Usage in lib file:
#   { lib, mkLibOptionFromFileName, ... }:
#   {
#     options.lib = mkLibOptionFromFileName {
#       # name auto-derived from filename
#       type = lib.types.functionTo lib.types.int;
#       fn = x: x * 2;
#       tests = { ... };
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
