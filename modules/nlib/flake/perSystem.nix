# nlib perSystem flake.parts module
#
# Defines nlib.lib for per-system libs inside the perSystem block:
#
#   perSystem = { pkgs, lib, config, ... }: {
#     nlib.lib.writeGreeting = {
#       type = lib.types.functionTo lib.types.package;
#       fn = name: pkgs.writeText "greeting" "Hello, ${name}!";
#       description = "Write a greeting file";
#       tests."greets Alice" = { args.name = "Alice"; expected = "greeting-Alice"; };
#     };
#   };
#
# The plain functions are auto-populated to lib.<name>
#
{ lib, ... }:
let
  libDefType = import ../_lib/libDefType.nix { inherit lib; };
in
{
  perSystem =
    { lib, config, ... }:
    let
      # Extract plain functions
      extractFns = defs: lib.mapAttrs (_: def: def.fn) defs;

      # Get lib definitions from nlib.lib
      perSystemLibDefs = config.nlib.lib or { };
      perSystemFns = extractFns perSystemLibDefs;
    in
    {
      # Define options.nlib.lib for per-system lib definitions
      options.nlib.lib = lib.mkOption {
        type = lib.types.attrsOf libDefType;
        default = { };
        description = ''
          Per-system lib definitions. Use for libs that depend on pkgs.

          Usage:
          ```nix
          perSystem = { pkgs, lib, config, ... }: {
            nlib.lib.writeGreeting = {
              type = lib.types.functionTo lib.types.package;
              fn = name: pkgs.writeText "greeting" "Hello, ''${name}!";
              description = "Write a greeting file";
              tests."greets Alice" = { args.name = "Alice"; expected = "greeting-Alice"; };
            };
          };
          ```

          The plain functions are auto-populated to lib.<name>
        '';
      };

      # Define options.lib for the extracted functions (output)
      options.lib = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.unspecified;
        default = { };
        description = "Per-system lib functions (auto-populated from nlib.lib)";
      };

      options.nlib.namespace = lib.mkOption {
        type = lib.types.str;
        default = "lib";
        description = "Namespace for this system's libs in flake.lib output";
      };

      # Export evaluated libs
      config = {
        # Auto-populate lib with extracted functions
        lib = perSystemFns;

        # Auto-expose to legacyPackages.nlib for external access
        legacyPackages.nlib = perSystemFns;
      };
    };
}
