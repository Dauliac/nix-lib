# nlib.collectors (flake-only)
#
# Collectors aggregate libs from different module systems (NixOS, home-manager, etc.)
# into the flake output. Uses adapterDefs for configuration.
#
# System-aware collection:
#   - Pure flake libs → flake.lib.flake.*
#   - Module system libs → legacyPackages.<sys>.lib.<ns>.*
#   - perSystem libs → legacyPackages.<sys>.lib.*
#
{ lib, config, ... }:
let
  cfg = config.nlib;
  adapterDefs = cfg.adapterDefs or { };

  # Collector definition submodule type (legacy, for backwards compat)
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

        systemPath = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Path to extract system from configuration";
          example = [
            "config"
            "nixpkgs"
            "hostPlatform"
            "system"
          ];
        };

        namespace = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Output namespace in legacyPackages.<sys>.lib.<namespace>";
        };

        description = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Documentation for this collector";
        };
      };
    }
  );

  # Enhanced mkCollector factory supporting flat (system-aware) and perSystem paths
  # Returns: { system -> { libName -> fn } }
  # Includes nested libs from _nestedFns under their nested namespace (e.g., nixos.home.*)
  mkSystemAwareCollector =
    {
      pathType,
      configPath,
      systemPath,
      attr,
      ...
    }:
    flakeCfg:
    if pathType == "flat" then
      let
        configs = lib.attrByPath configPath { } flakeCfg.flake;
        # Group libs by system, including nested libs under their namespace
        grouped = lib.foldl' (
          acc: name:
          let
            cfg' = configs.${name} or { };
            # Handle empty systemPath - default to "unknown" when path is empty
            system = if systemPath == [ ] then "unknown" else lib.attrByPath systemPath "unknown" cfg';
            # Own libs
            ownLibs = cfg'.config.nlib.${attr} or { };
            # Nested libs from this config (e.g., _nestedFns.home, _nestedFns.vim)
            # These become nested attrs: lib.nixos.home.*, lib.nixos.vim.*
            nestedFns = cfg'.config.nlib._nestedFns or { };
            # Merge own libs with nested namespaces
            libs = ownLibs // nestedFns;
            existing = acc.${system} or { };
          in
          if libs == { } then acc else acc // { ${system} = existing // libs; }
        ) { } (lib.attrNames configs);
      in
      grouped
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
        if target == { } then acc else acc // { ${system} = target; }
      ) { } systems
    else
      { };

  # Legacy flat collector (merges all systems, for backwards compat)
  # Includes nested libs from _nestedFns under their nested namespace
  mkFlatCollector =
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
        # Collect own libs and nested libs from all configs
        collected = lib.foldl' (
          acc: configName:
          let
            cfg' = configs.${configName} or { };
            ownLibs = cfg'.config.nlib.${attr} or { };
            # Nested libs become nested attrs (e.g., lib.nixos.home.*)
            nestedFns = cfg'.config.nlib._nestedFns or { };
          in
          lib.recursiveUpdate acc (ownLibs // nestedFns)
        ) { } (lib.attrNames configs);
      in
      collected
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

  # Remap collectors to use namespace as key (e.g., "home" instead of "home-manager")
  remapByNamespace =
    defs:
    lib.foldl' (
      acc: name:
      let
        def = defs.${name};
        ns = def.namespace;
      in
      acc // { ${ns} = def; }
    ) { } (lib.attrNames defs);

  enabledDefsByNamespace = remapByNamespace enabledDefs;

  # Build collector defs from adapterDefs
  adapterCollectorDefs = lib.mapAttrs (
    name: def:
    lib.mkDefault {
      enable = def.collector.enable or true;
      pathType = if def.collector.configPath or [ ] == [ ] then "perSystem" else "flat";
      configPath = def.collector.configPath or [ ];
      systemPath = def.collector.systemPath or [ ];
      namespace = def.namespace or name;
      description = "${name} configuration libs";
    }
  ) (lib.filterAttrs (_: def: def.enable or true) adapterDefs);
in
{
  options.nlib.collectorDefs = lib.mkOption {
    type = lib.types.attrsOf collectorDefType;
    default = { };
    description = ''
      Collector definitions. Each collector specifies how to gather libs
      from a module system and export them to legacyPackages.<sys>.lib.<namespace>.

      Example:
      ```nix
      nlib.collectorDefs.mySystem = {
        pathType = "flat";
        configPath = [ "myConfigurations" ];
        systemPath = [ "config" "nixpkgs" "system" ];
        namespace = "my";
        description = "Custom module system libs";
      };
      ```
    '';
  };

  # System-aware collectors (new API)
  options.nlib.systemCollectors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.lazyAttrsOf lib.types.unspecified));
    default = { };
    description = "System-aware collectors: namespace -> (flakeCfg -> { system -> { name -> fn } })";
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

  # Built-in collectors from adapterDefs
  config.nlib.collectorDefs = adapterCollectorDefs;

  # Generate system-aware collector functions
  config.nlib.systemCollectors = lib.mapAttrs (
    _: def: mkSystemAwareCollector (def // { attr = "_fns"; })
  ) enabledDefsByNamespace;

  # Generate legacy flat collector functions (backwards compat)
  config.nlib.collectors = lib.mapAttrs (
    _: def: mkFlatCollector (def // { attr = "_fns"; })
  ) enabledDefsByNamespace;

  config.nlib.metaCollectors = lib.mapAttrs (
    _: def: mkFlatCollector (def // { attr = "_libsMeta"; })
  ) enabledDefsByNamespace;
}
