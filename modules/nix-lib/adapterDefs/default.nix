# nix-lib.adapterDefs - Unified adapter definitions
#
# Declaratively define module system adapters with their:
# - Namespace (e.g., "home" for home-manager)
# - Collector configuration (path to configs, system detection)
# - Nested system propagation (e.g., NixOS -> home-manager -> nixvim)
# - Built-in lib flag (whether system has options.lib)
#
# Usage:
#   # Add custom module system
#   nix-lib.adapterDefs.devenv = {
#     namespace = "devenv";
#     hasBuiltinLib = false;
#     collector.configPath = [ "devenvConfigurations" ];
#     collector.systemPath = [ "pkgs" "system" ];
#   };
#
#   # Extend existing system with custom nesting
#   nix-lib.adapterDefs.nixos.nestedSystems = lib.mkForce [
#     { name = "home"; path = [ "home-manager" "users" ]; multi = true; }
#     { name = "custom"; path = [ "myModule" ]; }
#   ];
#
{ lib, ... }:
let
  adapterDefType = import ./_types/adapterDefType.nix { inherit lib; };
in
{
  imports = [
    ./builtins/nixos.nix
    ./builtins/home-manager.nix
    ./builtins/nix-darwin.nix
    ./builtins/nixvim.nix
    ./builtins/system-manager.nix
    ./builtins/wrappers.nix
    ./builtins/perSystem.nix
  ];

  options.nix-lib.adapterDefs = lib.mkOption {
    type = lib.types.attrsOf adapterDefType;
    default = { };
    description = ''
      Adapter definitions for module systems.

      Each adapter defines:
      - namespace: Output path in config.lib and legacyPackages.<sys>.lib
      - hasBuiltinLib: Whether system has built-in options.lib
      - collector: How to gather libs at flake level (path, system detection)
      - nestedSystems: Nested module systems to propagate libs from

      Example:
      ```nix
      nix-lib.adapterDefs.mySystem = {
        namespace = "my";
        hasBuiltinLib = false;
        collector.configPath = [ "myConfigurations" ];
        collector.systemPath = [ "pkgs" "system" ];
        nestedSystems = [
          { name = "sub"; path = [ "subModule" ]; }
        ];
      };
      ```
    '';
  };
}
