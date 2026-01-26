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
{ lib, ... }:
let
  nlibLib = import ../lib { inherit lib; };
in
{
  imports = [ ../options.nix ];

  options.nlib.collectors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.lazyAttrsOf lib.types.unspecified));
    default = { };
    description = ''
      Functions to collect libs from other sources.
      Each collector receives config and returns an attrset of libs.

      Example:
      ```nix
      nlib.collectors.nixos = config:
        lib.mapAttrs (_: host: host.config.nlib._libs or {})
          (config.flake.nixosConfigurations or {});
      ```
    '';
  };

  config =
    { config, ... }:
    let
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
      # Structure: { namespace = { fnName = libDef; }; }
      allLibsByNamespace = { ${cfg.namespace} = flakeLibs; } // collectedLibs;

      # Flatten for tests/coverage (all libs regardless of namespace)
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
      # Default collectors for known module systems
      nlib.collectors = {
        # Collect from nixosConfigurations
        nixos = cfg': lib.foldl' (acc: name:
          let
            hostLibs = cfg'.flake.nixosConfigurations.${name}.config.nlib._libs or { };
          in
          acc // hostLibs
        ) { } (lib.attrNames (cfg'.flake.nixosConfigurations or { }));

        # Collect from homeConfigurations (flake-parts or standalone)
        home = cfg': lib.foldl' (acc: name:
          let
            userLibs = cfg'.flake.homeConfigurations.${name}.config.nlib._libs or { };
          in
          acc // userLibs
        ) { } (lib.attrNames (cfg'.flake.homeConfigurations or { }));
      };

      # Expose library functions by namespace
      flake.lib = lib.mapAttrs (_: extractFns) allLibsByNamespace // {
        # Expose nlib helpers for consumers
        nlib = {
          inherit (nlibLib) mkLibOption mkLibOptionFromFileName wrapLibModule mkAdapter;
        };
      };

      # Expose tests in backend format
      flake.tests.${cfg.namespace} = tests;

      # Coverage enforcement
      assertions = lib.optional (cfg.coverage.threshold > 0) {
        assertion = coverageResult.percent >= cfg.coverage.threshold;
        message = "nlib: test coverage ${toString coverageResult.percent}% is below threshold ${toString cfg.coverage.threshold}%";
      };
    };
}
