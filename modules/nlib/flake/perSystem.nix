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
  libDefTypeModule = import ../_lib/libDefType.nix { inherit lib; };
  inherit (libDefTypeModule) flattenLibs unflattenFns extractFnsFlat;
in
{
  perSystem =
    { lib, config, ... }:
    let
      # Flatten nested lib definitions
      flatLibDefs = flattenLibs "" (config.nlib.lib or { });

      # Get lib definitions, flatten, extract, unflatten
      perSystemFns = unflattenFns (extractFnsFlat flatLibDefs);
    in
    {
      # Define options.nlib.lib for per-system lib definitions
      # Supports nested namespaces
      options.nlib.lib = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.unspecified;
        default = { };
        description = ''
          Per-system lib definitions. Use for libs that depend on pkgs.
          Supports nested namespaces.

          Usage:
          ```nix
          perSystem = { pkgs, lib, config, ... }: {
            nlib.lib.writeGreeting = {
              type = lib.types.functionTo lib.types.package;
              fn = name: pkgs.writeText "greeting" "Hello, ''${name}!";
              description = "Write a greeting file";
              tests."greets Alice" = { args.name = "Alice"; expected = "greeting-Alice"; };
            };

            # Nested namespace
            nlib.lib.scripts.hello = {
              type = lib.types.functionTo lib.types.package;
              fn = msg: pkgs.writeShellScriptBin "hello" "echo ''${msg}";
              description = "Create hello script";
            };
          };
          ```

          Functions are available at lib.<path> (e.g., lib.scripts.hello)
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
