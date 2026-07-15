# withLib - Composable facade for injecting options-phase libs
#
# Wraps any mkFlake-like function, extending lib via specialArgs so
# libs are available during ALL module phases (imports, options, config).
#
# This enables the composition pattern:
#   (nix-lib.withLib { optionsLib = {...}; } flake-parts.lib.mkFlake)
#     { inherit inputs; }
#     modules
#
# In modules, access via lib.{namespace}.*:
#   { lib, ... }:
#   {
#     options.foo = lib.ezci.mkSyncOptions { ... };  # Available in options phase!
#   }
#
# For config/perSystem phase, continue using lib.flake.* output layer:
#   { config, ... }:
#   let inherit (config.lib.flake) mkShellScript; in { ... }
#
{ lib }:
{
  # Libs to inject for options phase access
  # Should be an attrset of functions/values to add to lib.{namespace}
  optionsLib,
  # Namespace under lib where optionsLib will be available (default: "optionsLib")
  # Example: namespace = "ezci" -> lib.ezci.mkSyncOptions
  namespace ? "optionsLib",
  # Base lib to extend (default: nixpkgs lib from the wrapped function's inputs)
  # Usually you don't need to specify this
  baseLib ? null,
}:
# The mkFlake-like function to wrap (e.g., flake-parts.lib.mkFlake)
mkFlakeFn:
# Forward all args to wrapped function, extending lib via specialArgs
args: module:
let
  # Get base lib from args.specialArgs.lib, or use provided baseLib, or fall back to current lib
  originalLib = args.specialArgs.lib or (if baseLib != null then baseLib else lib);

  # Extend lib with the optionsLib under the specified namespace
  extendedLib = originalLib.extend (
    final: prev: {
      ${namespace} = optionsLib;
    }
  );
in
mkFlakeFn (
  args
  // {
    specialArgs = (args.specialArgs or { }) // {
      lib = extendedLib;
    };
  }
) module
