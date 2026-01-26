# nlib._libs (internal)
{ lib, ... }:
{
  options.nlib._libs = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    internal = true;
    description = "Evaluated libs (internal, set by adapter)";
  };
}
