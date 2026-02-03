# legacyPackages.lib (perSystem)
#
# Exports collected libs to legacyPackages.<sys>.lib.<ns>.<name>
# Also creates nested aliases (e.g., lib.home = lib.nixos.home)
#
{ lib, config, ... }:
let
  cfg = config.nix-lib;

  # System-aware collection: { namespace -> { system -> libs } }
  collectedByNamespaceBySystem = cfg._collectedBySystem or { };

  # Build per-system lib structure
  # { namespace -> { system -> libs } } => function(system) -> { namespace -> libs }
  buildSystemLibs =
    system:
    let
      # Collect libs for this system from all namespaces
      byNamespace = lib.mapAttrs (
        _namespace: bySystem: bySystem.${system} or { }
      ) collectedByNamespaceBySystem;

      # Filter out empty namespaces
      nonEmpty = lib.filterAttrs (_: libs: libs != { }) byNamespace;

      # Build nested aliases (e.g., lib.home = lib.nixos.home)
      nestedAliases = lib.foldl' (
        acc: namespace:
        let
          libs = nonEmpty.${namespace} or { };
          # Check for nested namespaces in libs (e.g., nixos.home)
          nestedNames = lib.filter (
            n: lib.isAttrs (libs.${n} or null) && !(lib.isFunction (libs.${n} or null))
          ) (lib.attrNames libs);
        in
        lib.foldl' (
          acc': nestedName:
          # Create alias: lib.home = lib.nixos.home
          acc' // { ${nestedName} = libs.${nestedName}; }
        ) acc nestedNames
      ) { } (lib.attrNames nonEmpty);
    in
    nonEmpty // nestedAliases;
in
{
  # Per-system configuration: export libs to legacyPackages.<sys>.lib.<ns>
  perSystem =
    { system, ... }:
    let
      systemLibs = buildSystemLibs system;
    in
    {
      # Merge with existing legacyPackages.lib (from lib/perSystem.nix)
      config.legacyPackages.lib = systemLibs;
    };
}
