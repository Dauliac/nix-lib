# nix-lib._libs, nix-lib._libsMeta, nix-lib._flakeLibsMeta (internal)
#
# Internal storage options for evaluated libs and metadata.
# Used by adapters and collectors for data passing between modules.
#
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

  # Store system-aware collection for legacyPackages export
  options.nix-lib._collectedBySystem = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    internal = true;
    description = "System-aware collected libs for legacyPackages export";
  };
}
