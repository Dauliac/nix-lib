# evalLibModules - Evaluate lib modules
#
# Takes a list of lib modules and evaluates them into a unified lib attrset.
# Lib modules can be:
#   - Nix files: { lib, config, ... }: { lib.math.double = { fn = x: x * 2; }; }
#   - Attrsets for imports: { inherit soonix; } -> evaluates soonix.lib
#
# Returns: { fns, meta, tests }
#   - fns: nested attrset of functions (lib.math.double, lib.string.format, etc.)
#   - meta: metadata for docs/linting
#   - tests: test definitions for all libs
#
{ lib }:
let
  libDefTypeModule = import ./libDefType.nix { inherit lib; };
  inherit (libDefTypeModule)
    flattenLibs
    unflattenFns
    extractFnsFlat
    libDefsToMeta
    ;
  backendsModule = import ./backends.nix { inherit lib; };
  inherit (backendsModule) toBackend;
in
{
  modules,
  # Extra arguments passed to lib modules
  extraArgs ? { },
}:
let
  # Process import-style modules: { inherit soonix; } -> soonix.lib
  # vs regular modules: { lib, ... }: { lib.foo = ...; }
  processModule =
    mod:
    if builtins.isFunction mod then
      # Regular module function
      mod
    else if builtins.isPath mod then
      # Path to a module file - import it
      import mod
    else if builtins.isAttrs mod then
      # Check if it's an import-style { inherit foo; } or inline lib defs
      let
        keys = builtins.attrNames mod;
        firstKey = builtins.head keys;
        firstVal = mod.${firstKey};
      in
      # If the value has a .lib attribute, it's an external input
      if builtins.length keys == 1 && (firstVal.lib or null) != null then
        # External input: { inherit soonix; } -> { lib.soonix = soonix.lib; }
        { lib, ... }:
        {
          lib.${firstKey} = firstVal.lib;
        }
      else
        # Inline lib definitions or regular module attrset
        { lib, ... }: mod
    else if builtins.isList mod then
      # List of modules - should be flattened before passing
      throw "evalLibModules: lists should be flattened before passing"
    else
      throw "evalLibModules: invalid module type: ${builtins.typeOf mod}";

  # Convert all modules to standard module format
  normalizedModules = map processModule modules;

  # Lib module type definition
  libModuleType = lib.types.submodule {
    options.lib = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = { };
      description = "Lib definitions";
    };
  };

  # Evaluate modules using nixpkgs module system
  evaluated = lib.evalModules {
    modules = normalizedModules ++ [
      {
        options.lib = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.unspecified;
          default = { };
          description = "Lib definitions organized by namespace";
        };
      }
    ];
    specialArgs = {
      inherit lib;
    }
    // extraArgs;
  };

  # Get the evaluated lib config
  libConfig = evaluated.config.lib;

  # Flatten lib definitions for processing
  flatLibDefs = flattenLibs "" libConfig;

  # Extract functions
  extractedFns = extractFnsFlat flatLibDefs;

  # Build nested structure
  nestedFns = unflattenFns extractedFns;

  # Generate metadata
  meta = libDefsToMeta flatLibDefs nestedFns;

  # Generate tests
  tests = toBackend "nix-unit" meta;

in
{
  # The actual functions, nested: { math.double, string.format, ... }
  fns = nestedFns;

  # Metadata for docs/linting
  inherit meta;

  # Tests for nix-unit
  inherit tests;

  # Raw flat definitions (for advanced use)
  _flat = flatLibDefs;
}
