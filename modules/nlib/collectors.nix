# nlib.collectors (flake-only)
#
# Collectors aggregate libs from different module systems (NixOS, home-manager, etc.)
# into the flake output. Extensible via options.nlib.collectorDefs.
#
# Usage:
#   # Define custom collector
#   nlib.collectorDefs.mySystem = {
#     pathType = "flat";
#     configPath = [ "myConfigurations" ];
#     namespace = "my";
#   };
#
#   # Collected libs available at flake.lib.my.*
#
{ lib, config, ... }:
let
  cfg = config.nlib;

  # Collector definition submodule type
  collectorDefType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable this collector";
        };

        pathType = lib.mkOption {
          type = lib.types.enum [
            "flat"
            "perSystem"
          ];
          default = "flat";
          description = ''
            Collection strategy:
            - flat: Traverse flake.<configPath>.<name>.config.nlib.<attr>
            - perSystem: Traverse flake.legacyPackages.<system>.<configPath>
          '';
        };

        configPath = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Path to configuration set within flake outputs";
          example = [ "nixosConfigurations" ];
        };

        namespace = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Output namespace in flake.lib.<namespace>";
        };

        description = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Documentation for this collector";
        };
      };
    }
  );

  # Enhanced mkCollector factory supporting flat and perSystem paths
  mkCollector =
    {
      pathType,
      configPath,
      attr,
      ...
    }:
    flakeCfg:
    if pathType == "flat" then
      let
        configs = lib.attrByPath configPath { } flakeCfg.flake;
      in
      lib.foldl' (acc: name: acc // (configs.${name}.config.nlib.${attr} or { })) { } (
        lib.attrNames configs
      )
    else if pathType == "perSystem" then
      let
        systems = flakeCfg.systems or [ ];
        legacyPkgs = flakeCfg.flake.legacyPackages or { };
      in
      lib.foldl' (
        acc: system:
        let
          systemPkgs = legacyPkgs.${system} or { };
          target = lib.attrByPath configPath { } systemPkgs;
        in
        acc // target
      ) { } systems
    else
      { };

  # Filter enabled collectors
  enabledDefs = lib.filterAttrs (_: def: def.enable) cfg.collectorDefs;
in
{
  options.nlib.collectorDefs = lib.mkOption {
    type = lib.types.attrsOf collectorDefType;
    default = { };
    description = ''
      Collector definitions. Each collector specifies how to gather libs
      from a module system and export them to flake.lib.<namespace>.

      Example:
      ```nix
      nlib.collectorDefs.mySystem = {
        pathType = "flat";
        configPath = [ "myConfigurations" ];
        namespace = "my";
        description = "Custom module system libs";
      };
      ```
    '';
  };

  # Keep existing options for backward compatibility
  options.nlib.collectors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.lazyAttrsOf lib.types.unspecified));
    default = { };
    description = "Functions to collect libs from other sources (nixos, home-manager, etc).";
  };

  options.nlib.metaCollectors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.lazyAttrsOf lib.types.unspecified));
    default = { };
    internal = true;
    description = "Functions to collect lib metadata from other sources.";
  };

  # Built-in collectors (lower priority, user can override)
  config.nlib.collectorDefs = {
    nixos = lib.mkDefault {
      pathType = "flat";
      configPath = [ "nixosConfigurations" ];
      description = "NixOS configuration libs";
    };
    home = lib.mkDefault {
      pathType = "flat";
      configPath = [ "homeConfigurations" ];
      description = "home-manager configuration libs";
    };
    darwin = lib.mkDefault {
      pathType = "flat";
      configPath = [ "darwinConfigurations" ];
      description = "nix-darwin configuration libs";
    };
    vim = lib.mkDefault {
      pathType = "flat";
      configPath = [ "nixvimConfigurations" ];
      description = "nixvim configuration libs";
    };
    system = lib.mkDefault {
      pathType = "flat";
      configPath = [ "systemConfigs" ];
      description = "system-manager configuration libs";
    };
    perSystem = lib.mkDefault {
      pathType = "perSystem";
      configPath = [ "nlib" ];
      description = "Per-system libs from legacyPackages";
    };
  };

  # Generate collector functions from definitions
  config.nlib.collectors = lib.mapAttrs (_: def: mkCollector (def // { attr = "_fns"; })) enabledDefs;

  config.nlib.metaCollectors = lib.mapAttrs (
    _: def: mkCollector (def // { attr = "_libsMeta"; })
  ) enabledDefs;
}
