# nlib.libs option (legacy)
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.nlib.libs = mkOption {
    type = types.lazyAttrsOf types.unspecified;
    default = { };
    description = "Library functions created with mkLibOption (legacy, use perLib instead)";
  };
}
