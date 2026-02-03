# Main adapter definition type
#
# Combines namespace, collector config, and nested systems.
#
{ lib }:
let
  nestedSystemDefType = import ./nestedSystemDefType.nix { inherit lib; };
  collectorDefType = import ./collectorDefType.nix { inherit lib; };
in
lib.types.submodule (
  { name, ... }:
  {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable this adapter";
      };

      namespace = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = ''
          Output namespace in config.lib.<namespace> and legacyPackages.<sys>.lib.<namespace>.

          Example: "home" for home-manager makes libs available at
          config.lib.home.* within the module and legacyPackages.<sys>.lib.home.* at flake level.
        '';
      };

      hasBuiltinLib = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether the target module system has built-in options.lib.

          NixOS and home-manager have this, others typically don't.
          This affects how config.lib is populated (merge vs set).
        '';
      };

      collector = lib.mkOption {
        type = collectorDefType;
        default = { };
        description = "Collector configuration for gathering libs at flake level";
      };

      nestedSystems = lib.mkOption {
        type = lib.types.listOf nestedSystemDefType;
        default = [ ];
        description = ''
          Nested module systems to extract libs from.

          Allows NixOS to see home-manager libs at config.lib.home.*
          and nixvim libs at config.lib.home.vim.*
        '';
        example = [
          {
            name = "home";
            path = [
              "home-manager"
              "users"
            ];
            multi = true;
          }
        ];
      };
    };
  }
)
