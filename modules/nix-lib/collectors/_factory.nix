# Collector factory functions (internal)
#
# mkSystemAwareCollector - Groups libs by system
# mkFlatCollector - Merges all systems (legacy)
#
{ lib }:
let
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
            ownLibs = cfg'.config.nix-lib.${attr} or { };
            # Nested libs from this config (e.g., _nestedFns.home, _nestedFns.vim)
            # These become nested attrs: lib.nixos.home.*, lib.nixos.vim.*
            nestedFns = cfg'.config.nix-lib._nestedFns or { };
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
            ownLibs = cfg'.config.nix-lib.${attr} or { };
            # Nested libs become nested attrs (e.g., lib.nixos.home.*)
            nestedFns = cfg'.config.nix-lib._nestedFns or { };
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
in
{
  inherit mkSystemAwareCollector mkFlatCollector;
}
