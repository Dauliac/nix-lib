# nlib flake.parts module
{ lib, config, ... }:
let
  nlibLib = import ../lib { inherit lib; };
  cfg = config.nlib;

  evaluatedPerLib =
    if cfg.perLib == [ ] then
      { config.lib = { }; }
    else
      lib.evalModules {
        modules = cfg.perLib;
        specialArgs = {
          inherit lib;
          inherit (nlibLib) mkLibOption;
        };
      };

  flakeLibs = evaluatedPerLib.config.lib or { };
  collectedLibs = lib.mapAttrs (_: collector: collector config) cfg.collectors;
  allLibsByNamespace = { ${cfg.namespace} = flakeLibs; } // collectedLibs;
  allLibsFlat = lib.foldl' (acc: libs: acc // libs) { } (lib.attrValues allLibsByNamespace);

  getMeta = def: def._nlib or def;
  extractFns = libs: lib.mapAttrs (_: d: (getMeta d).fn or d.fn or d) libs;
  tests = nlibLib.backends.toBackend cfg.testing.backend allLibsFlat;
in
{
  imports = [
    ../options
    ../options/collectors.nix
  ];

  config = {
    flake.lib = lib.mapAttrs (_: extractFns) allLibsByNamespace // {
      nlib = {
        inherit (nlibLib) mkLibOption mkLibOptionFromFileName wrapLibModule mkAdapter;
      };
    };

    flake.tests.${cfg.namespace} = tests;
  };
}
