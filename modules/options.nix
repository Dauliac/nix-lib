# Shared nlib options - imported by all adapters
#
# This module defines the common interface for nlib across all module systems
# (flake-parts, NixOS, home-manager, nixvim, nix-darwin, etc.)
{ lib, ... }:
let
  inherit (lib) mkOption types;

  # deferredModule type for perLib (allows merging multiple module contributions)
  deferredModuleWith =
    { staticModules ? [ ] }:
    types.mkOptionType {
      name = "deferredModule";
      description = "module";
      check = x: builtins.isAttrs x || builtins.isFunction x || lib.isPath x;
      merge =
        loc: defs:
        staticModules ++ map (def: lib.setDefaultModuleLocation "nlib.perLib" def.value) defs;
    };
in
{
  options.nlib = {
    enable = lib.mkEnableOption "nlib library definitions";

    namespace = mkOption {
      type = types.str;
      default = "lib";
      description = "Namespace for this module system's libs";
      example = "nixos";
    };

    perLib = mkOption {
      type = deferredModuleWith { };
      default = [ ];
      description = ''
        Per-lib module configuration. Modules contribute to options.lib which merge together.

        Usage:
        ```nix
        nlib.perLib = { lib, mkLibOption, ... }: {
          options.lib = mkLibOption {
            name = "myFunc";
            type = lib.types.functionTo lib.types.int;
            fn = x: x * 2;
            description = "Double the input";
            tests = { "works" = { args = { x = 5; }; expected = 10; }; };
          };
        };
        ```
      '';
    };

    testing.backend = mkOption {
      type = types.enum [
        "nix-unit"
        "nixt"
        "nixtest"
        "runTests"
      ];
      default = "nix-unit";
      description = "Test framework backend to use";
    };

    coverage.threshold = mkOption {
      type = types.ints.between 0 100;
      default = 100;
      description = "Minimum test coverage percentage required (0 = disabled)";
    };

    # Output: evaluated libs (set by adapter)
    _libs = mkOption {
      type = types.lazyAttrsOf types.unspecified;
      default = { };
      internal = true;
      description = "Evaluated libs (internal, set by adapter)";
    };
  };
}
