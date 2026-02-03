# nix-lib._libs (internal)
{ lib, ... }:
{
  options.nix-lib._libs = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    internal = true;
    description = "Evaluated libs (internal, set by adapter)";
  };

  options.nix-lib._libsMeta = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    internal = true;
    description = "Lib metadata for test extraction (internal, set by adapter)";
  };

  options.nix-lib._flakeLibsMeta = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    internal = true;
    description = "Flake-level lib metadata (internal, set by flake module)";
  };
}
