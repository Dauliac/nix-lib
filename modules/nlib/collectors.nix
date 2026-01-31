# nlib.collectors (flake-only)
#
# Collectors aggregate libs from different module systems (NixOS, home-manager, etc.)
# into the flake output. Uses a factory pattern to avoid code duplication.
{ lib, ... }:
let
  # Factory to create collector functions
  # configPath: flake attribute path (e.g., ["nixosConfigurations"])
  # attr: nlib attribute to collect ("_fns" or "_libsMeta")
  mkCollector =
    { configPath, attr }:
    cfg:
    let
      configs = lib.attrByPath configPath { } cfg.flake;
    in
    lib.foldl' (acc: name: acc // (configs.${name}.config.nlib.${attr} or { })) { } (
      lib.attrNames configs
    );

  # Configuration for each namespace
  collectorConfigs = {
    nixos = {
      configPath = [ "nixosConfigurations" ];
    };
    home = {
      configPath = [ "homeConfigurations" ];
    };
    darwin = {
      configPath = [ "darwinConfigurations" ];
    };
    vim = {
      configPath = [ "nixvimConfigurations" ];
    };
    system = {
      configPath = [ "systemConfigs" ];
    };
  };
in
{
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

  # Collectors use _fns which includes both own libs and nested propagated libs
  config.nlib.collectors = lib.mapAttrs (_: cfg: mkCollector (cfg // { attr = "_fns"; })) collectorConfigs;

  # Meta collectors use _libsMeta for test metadata
  config.nlib.metaCollectors = lib.mapAttrs (
    _: cfg: mkCollector (cfg // { attr = "_libsMeta"; })
  ) collectorConfigs;
}
