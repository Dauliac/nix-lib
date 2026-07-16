# mkLib - Create typed libs for non-flake-parts flakes
#
# For flakes that don't use flake-parts but want nlib's features:
# - Type definitions
# - Built-in testing (multiple backends)
# - Self-referencing functions via fixed-point
# - Nested namespaces
#
# Usage:
#   outputs = { nixpkgs, nlib, ... }:
#     nlib.lib.mkLib {
#       inherit nixpkgs;
#       namespace = "mylib";
#       backend = "nix-unit";
#
#       libs = self: {
#         double = {
#           type = self.types.functionTo self.types.int;
#           fn = x: x * 2;
#           description = "Double a number";
#           tests."doubles 5" = { args.x = 5; expected = 10; };
#         };
#
#         quadruple = {
#           type = self.types.functionTo self.types.int;
#           fn = x: self.fns.double (self.fns.double x);
#           description = "Quadruple using double";
#         };
#       };
#     };
#
# Returns: { lib.<namespace>.*, tests.* }
#
{ lib }:
let
  libDefTypeModule = import ./libDefType.nix { inherit lib; };
  backendsModule = import ./backends.nix { inherit lib; };

  inherit (libDefTypeModule)
    flattenLibs
    unflattenFns
    libDefsToMeta
    extractFnsFlat
    ;

  inherit (backendsModule) toBackend;
in
{
  nixpkgs,
  libs,
  namespace ? "standalone",
  backend ? "nix-unit",
}:
let
  # Extract lib from nixpkgs (handle both flake input and evaluated nixpkgs)
  nixpkgsLib = nixpkgs.lib or (import nixpkgs { system = "x86_64-linux"; }).lib;

  # Generate functions from flattened definitions
  generateFns =
    defs:
    lib.foldl' (
      acc: attrName:
      let
        def = defs.${attrName};
        path = lib.splitString "." attrName;
      in
      lib.recursiveUpdate acc (lib.setAttrByPath path def.fn)
    ) { } (builtins.attrNames defs);

  # Resolve libs using fixed-point for self-reference
  # The `self` parameter provides:
  #   - self.fns: resolved functions (for cross-references)
  #   - self.types: lib.types (for type definitions)
  #   - self.lib: full nixpkgs lib (for utilities)
  resolvedLibDefs = lib.fix (
    self:
    let
      # Call user's libs function with self context
      rawDefs = libs {
        fns = generateFns (flattenLibs "" self);
        types = lib.types;
        inherit lib;
      };
    in
    rawDefs
  );

  # Flatten definitions for processing
  flatLibDefs = flattenLibs "" resolvedLibDefs;

  # Extract plain functions (only visible ones)
  extractedFns = extractFnsFlat flatLibDefs;

  # Build nested structure for output
  nestedFns = unflattenFns extractedFns;

  # Generate resolved functions for self-reference and testing
  resolvedFns = generateFns flatLibDefs;

  # Convert to metadata format for test backends
  libsMeta = libDefsToMeta flatLibDefs resolvedFns;

  # Generate tests using selected backend
  tests = toBackend backend libsMeta;

in
{
  # Output: lib.<namespace>.*
  lib.${namespace} = nestedFns;

  # Output: tests.* (for nix-unit, etc.)
  inherit tests;

  # Internal: metadata for documentation generation
  _meta = libsMeta;

  # Internal: raw resolved functions
  _fns = resolvedFns;
}
