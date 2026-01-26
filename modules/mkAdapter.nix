# mkAdapter - Factory to create nlib adapters for any module system
#
# Usage:
#   # In NixOS config:
#   imports = [ (nlib.mkAdapter { name = "nixos"; }) ];
#
#   # In home-manager:
#   imports = [ (nlib.mkAdapter { name = "home-manager"; }) ];
#
#   # In nixvim:
#   imports = [ (nlib.mkAdapter { name = "nixvim"; }) ];
#
# The adapter:
#   1. Imports shared options (nlib.perLib, nlib.testing, etc.)
#   2. Evaluates perLib modules when nlib.enable = true
#   3. Exposes evaluated libs via nlib._libs
{ lib }:
let
  nlibLib = import ./lib { inherit lib; };
in
{
  # Default namespace for each known module system
  namespaces ? {
    nixos = "nixos";
    home-manager = "home";
    nixvim = "vim";
    nix-darwin = "darwin";
    flake = "lib";
  },
}:
{
  # Module system name (e.g., "nixos", "home-manager", "nixvim")
  name,
  # Optional: override default namespace
  namespace ? namespaces.${name} or name,
}:
# Return a NixOS-style module
{
  config,
  lib,
  ...
}:
let
  cfg = config.nlib;

  # Evaluate perLib modules to get lib options
  evaluatedPerLib =
    if !cfg.enable || cfg.perLib == [ ] then
      { config.lib = { }; }
    else
      lib.evalModules {
        modules = cfg.perLib;
        specialArgs = {
          inherit lib;
          inherit (nlibLib) mkLibOption;
          mkLibOptionFromFileName = nlibLib.mkLibOptionFromFileName;
        };
      };

  allLibs = evaluatedPerLib.config.lib or { };
in
{
  imports = [ ./options.nix ];

  config = {
    # Set default namespace based on module system
    nlib.namespace = lib.mkDefault namespace;

    # Expose evaluated libs for collection
    nlib._libs = allLibs;
  };
}
