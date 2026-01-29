# nlib perSystem flake.parts module
#
# Defines config.lib for per-system libs inside the perSystem block:
#
#   perSystem = { pkgs, lib, config, ... }: {
#     lib.writeGreeting = {
#       type = lib.types.functionTo lib.types.package;
#       fn = name: pkgs.writeText "greeting" "Hello, ${name}!";
#       description = "Write a greeting file";
#       tests."greets Alice" = { args.name = "Alice"; expected = "greeting-Alice"; };
#     };
#   };
#
{ lib, ... }:
let
  libDefType = import ../_lib/libDefType.nix { inherit lib; };
in
{
  perSystem =
    { lib, config, ... }:
    let
      # Convert lib definitions to metadata format

      # Extract plain functions
      extractFns = defs: lib.mapAttrs (_: def: def.fn) defs;

      # Get lib definitions from config.lib
      perSystemLibDefs = config.lib or { };
      perSystemFns = extractFns perSystemLibDefs;

    in
    {
      # Define options.lib for per-system libs
      options.lib = lib.mkOption {
        type = lib.types.attrsOf libDefType;
        default = { };
        description = ''
          Per-system lib definitions. Use for libs that depend on pkgs.

          Usage:
          ```nix
          perSystem = { pkgs, lib, config, ... }: {
            lib.writeGreeting = {
              type = lib.types.functionTo lib.types.package;
              fn = name: pkgs.writeText "greeting" "Hello, ''${name}!";
              description = "Write a greeting file";
              tests."greets Alice" = { args.name = "Alice"; expected = "greeting-Alice"; };
            };
          };
          ```
        '';
      };

      options.nlib.namespace = lib.mkOption {
        type = lib.types.str;
        default = "lib";
        description = "Namespace for this system's libs in flake.lib output";
      };

      # Export evaluated libs
      config = {
        # Auto-expose to legacyPackages.nlib for external access
        legacyPackages.nlib = perSystemFns;
      };
    };
}
