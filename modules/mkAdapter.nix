# mkAdapter - Factory to create nlib adapters for any module system
#
# Usage:
#   imports = [ (nlib.mkAdapter { name = "nixos"; }) ];
#   imports = [ (nlib.mkAdapter { name = "home-manager"; }) ];
#   imports = [ (nlib.mkAdapter { name = "nixvim"; }) ];
{ lib }:
let
  nlibLib = import ./lib { inherit lib; };

  namespaces = {
    nixos = "nixos";
    home-manager = "home";
    nixvim = "vim";
    nix-darwin = "darwin";
    flake = "lib";
  };
in
{
  name,
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

  evaluatedPerLib =
    if !cfg.enable || cfg.perLib == [ ] then
      { config.lib = { }; }
    else
      lib.evalModules {
        modules = cfg.perLib;
        specialArgs = {
          inherit lib;
          inherit (nlibLib) mkLibOption;
        };
      };

  allLibs = evaluatedPerLib.config.lib or { };
in
{
  imports = [ ./options ];

  config = {
    nlib.namespace = lib.mkDefault namespace;
    nlib._libs = allLibs;
  };
}
