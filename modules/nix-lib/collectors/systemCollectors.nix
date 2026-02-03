# nix-lib.systemCollectors, nix-lib.collectors
#
# Auto-generated collector functions from collectorDefs.
# - systemCollectors: System-aware (new API)
# - collectors: Flat/merged (legacy backwards compat)
#
{ lib, config, ... }:
let
  cfg = config.nix-lib;
  factory = import ./_factory.nix { inherit lib; };
  inherit (factory) mkSystemAwareCollector mkFlatCollector;

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
in
{
  # System-aware collectors (new API)
  options.nix-lib.systemCollectors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.lazyAttrsOf lib.types.unspecified));
    default = { };
    description = "System-aware collectors: namespace -> (flakeCfg -> { system -> { name -> fn } })";
  };

  # Keep existing options for backward compatibility
  options.nix-lib.collectors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.lazyAttrsOf lib.types.unspecified));
    default = { };
    description = "Functions to collect libs from other sources (nixos, home-manager, etc).";
  };

  # Generate system-aware collector functions
  config.nix-lib.systemCollectors = lib.mapAttrs (
    _: def: mkSystemAwareCollector (def // { attr = "_fns"; })
  ) enabledDefsByNamespace;

  # Generate legacy flat collector functions (backwards compat)
  config.nix-lib.collectors = lib.mapAttrs (
    _: def: mkFlatCollector (def // { attr = "_fns"; })
  ) enabledDefsByNamespace;
}
