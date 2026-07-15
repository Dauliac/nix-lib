# nix-lib.lib (perSystem)
#
# Per-system lib definitions (can depend on pkgs).
#
# Usage:
#   perSystem = { pkgs, lib, config, ... }: {
#     nix-lib.lib.writeGreeting = {
#       type = lib.types.functionTo lib.types.package;
#       fn = name: pkgs.writeText "greeting" "Hello, ${name}!";
#       description = "Write a greeting file";
#     };
#   };
#
# Import external libs (soonix-style, takes pkgs):
#   perSystem = { pkgs, ... }: {
#     nix-lib.imports = [
#       { input = soonix; namespace = "soonix"; }  # soonix.lib { inherit pkgs; } -> lib.soonix.*
#     ];
#   };
#
# Output: config.lib.<name>, legacyPackages.nix-lib.<name>
#
{ lib, ... }:
let
  libDefTypeModule = import ../_lib/libDefType.nix { inherit lib; };
  inherit (libDefTypeModule) flattenLibs unflattenFns extractFnsFlat;
in
{
  perSystem =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      # Flatten nested lib definitions
      flatLibDefs = flattenLibs "" (config.nix-lib.lib or { });

      # Get lib definitions, flatten, extract, unflatten
      perSystemFns = unflattenFns (extractFnsFlat flatLibDefs);

      # Process imported external libs (soonix-style, takes pkgs)
      # Each import is an attrset: { namespace = input; }
      # e.g., { inherit soonix; } or { custom = someLib; }
      # input.lib { inherit pkgs; } gets merged under namespace
      importedLibs = lib.foldl' (
        acc: importDef:
        let
          # Extract namespace (key) and input (value) from the single-attr set
          namespace = builtins.head (builtins.attrNames importDef);
          input = importDef.${namespace};
          # Call the lib function with pkgs
          inputLib = input.lib { inherit pkgs; };
        in
        lib.recursiveUpdate acc { ${namespace} = inputLib; }
      ) { } (config.nix-lib.imports or [ ]);
    in
    {
      # Define options.nix-lib.imports for importing external libs (soonix-style)
      options.nix-lib.imports = lib.mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.unspecified);
        default = [ ];
        description = ''
          Import external libs that need pkgs (soonix-style).

          Each element is an attrset where key = namespace, value = flake input.
          Use `{ inherit soonix; }` syntax for automatic namespacing.

          Usage:
          ```nix
          perSystem = { pkgs, ... }: {
            nix-lib.imports = [
              { inherit soonix; }       # soonix.lib { inherit pkgs; } -> lib.soonix.*
              { inherit anotherLib; }   # anotherLib.lib { inherit pkgs; } -> lib.anotherLib.*
              { custom = someLib; }     # someLib.lib { inherit pkgs; } -> lib.custom.*
            ];

            # Now available:
            # config.lib.soonix.mkShellHook
          };
          ```

          Each input must have a `lib` attribute that is a function taking { pkgs }.
        '';
      };

      # Define options.nix-lib.lib for per-system lib definitions
      # Supports nested namespaces
      options.nix-lib.lib = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.unspecified;
        default = { };
        description = ''
          Per-system lib definitions. Use for libs that depend on pkgs.
          Supports nested namespaces.

          Usage:
          ```nix
          perSystem = { pkgs, lib, config, ... }: {
            nix-lib.lib.writeGreeting = {
              type = lib.types.functionTo lib.types.package;
              fn = name: pkgs.writeText "greeting" "Hello, ''${name}!";
              description = "Write a greeting file";
              tests."greets Alice" = { args.name = "Alice"; expected = "greeting-Alice"; };
            };

            # Nested namespace
            nix-lib.lib.scripts.hello = {
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
        description = "Per-system lib functions (auto-populated from nix-lib.lib)";
      };

      options.nix-lib.namespace = lib.mkOption {
        type = lib.types.str;
        default = "lib";
        description = "Namespace for this system's libs in flake.lib output";
      };

      # Export evaluated libs
      config = {
        # Auto-populate lib with extracted functions + imported external libs
        lib = lib.recursiveUpdate importedLibs perSystemFns;

        # Auto-expose to legacyPackages.nix-lib for external access
        legacyPackages.nix-lib = lib.recursiveUpdate importedLibs perSystemFns;
      };
    };
}
