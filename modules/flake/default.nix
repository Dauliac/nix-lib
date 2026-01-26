# nlib flake.parts module
#
# Provides:
#   - flake.lib.{namespace}: Library functions (collected from all sources)
#   - flake.lib.nlib: mkLibOption helpers + mkAdapter
#   - flake.tests.{namespace}: Tests in selected backend format
#
# Collects libs from:
#   - nlib.perLib (flake-level)
#   - config.flake.nixosConfigurations.*.config.nlib._libs
#   - config.flake.homeConfigurations.*.config.nlib._libs (if present)
#   - Any other registered collectors
{
  lib,
  config,
  ...
}:
let
  nlibLib = import ../lib { inherit lib; };
  cfg = config.nlib;

  # Evaluate perLib modules to get flake-level libs
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

  # Flake-level libs
  flakeLibs = evaluatedPerLib.config.lib or { };

  # Collect libs from all registered collectors
  collectedLibs = lib.mapAttrs (_: collector: collector config) cfg.collectors;

  # Merge all libs: flake + all collectors
  allLibsByNamespace = { ${cfg.namespace} = flakeLibs; } // collectedLibs;

  # Flatten for tests/coverage
  allLibsFlat = lib.foldl' (acc: libs: acc // libs) { } (lib.attrValues allLibsByNamespace);

  # Extract functions from libs
  getMeta = def: def._nlib or def;
  extractFns = libs: lib.mapAttrs (_: d: (getMeta d).fn or d.fn or d) libs;

  # Transform tests to selected backend format
  tests = nlibLib.backends.toBackend cfg.testing.backend allLibsFlat;

  # Calculate coverage
  coverageResult = nlibLib.coverage.calculate allLibsFlat;
in
{
  imports = [ ../options.nix ];

  options.nlib.collectors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.lazyAttrsOf lib.types.unspecified));
    default = { };
    description = "Functions to collect libs from other sources.";
  };

  config = {
    # Default collectors for known module systems
    nlib.collectors = {
      nixos =
        cfg':
        lib.foldl'
          (
            acc: name:
            acc // (cfg'.flake.nixosConfigurations.${name}.config.nlib._libs or { })
          )
          { }
          (lib.attrNames (cfg'.flake.nixosConfigurations or { }));

      home =
        cfg':
        lib.foldl'
          (
            acc: name:
            acc // (cfg'.flake.homeConfigurations.${name}.config.nlib._libs or { })
          )
          { }
          (lib.attrNames (cfg'.flake.homeConfigurations or { }));
    };

    # Expose library functions by namespace
    flake.lib = lib.mapAttrs (_: extractFns) allLibsByNamespace // {
      nlib = {
        inherit (nlibLib) mkLibOption mkLibOptionFromFileName wrapLibModule mkAdapter;
      };
    };

    # Expose tests in backend format
    flake.tests.${cfg.namespace} = tests;

  };
}
