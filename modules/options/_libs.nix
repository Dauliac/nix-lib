# nlib._libs (internal)
{ lib, ... }:
{
  options.nlib._libs = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    internal = true;
    description = "Evaluated libs (internal, set by adapter)";
  };

  options.nlib._libsMeta = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    internal = true;
    description = "Lib metadata for test extraction (internal, set by adapter)";
  };
}
