# nix-lib.metaCollectors (internal)
#
# Auto-generated metadata collectors for test extraction.
#
{ lib, config, ... }:
let
  cfg = config.nix-lib;
  factory = import ./_factory.nix { inherit lib; };
  inherit (factory) mkFlatCollector;

  # Filter enabled collectors
  enabledDefs = lib.filterAttrs (_: def: def.enable) cfg.collectorDefs;

  # Remap collectors to use namespace as key
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
  options.nix-lib.metaCollectors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.lazyAttrsOf lib.types.unspecified));
    default = { };
    internal = true;
    description = "Functions to collect lib metadata from other sources.";
  };

  config.nix-lib.metaCollectors = lib.mapAttrs (
    _: def: mkFlatCollector (def // { attr = "_libsMeta"; })
  ) enabledDefsByNamespace;
}
