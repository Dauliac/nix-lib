# Example: Defining libs in nix-darwin module
#
# These are collected and available at: flake.lib.darwin.<name>
#
# Usage in darwinConfigurations:
#   modules = [
#     nlib.darwinModules.default
#     {
#       nlib.enable = true;
#       lib.myHelper = { ... };
#     }
#   ];
#
{ lib, config, ... }:
{
  nlib.enable = true;

  # Nix-darwin specific lib functions
  lib.mkBrewPackage = {
    type = lib.types.functionTo lib.types.attrs;
    fn = name: {
      homebrew.brews = [ name ];
    };
    description = "Add a homebrew package";
    tests."adds wget" = {
      args.name = "wget";
      expected = { homebrew.brews = [ "wget" ]; };
    };
  };

  lib.mkBrewCask = {
    type = lib.types.functionTo lib.types.attrs;
    fn = name: {
      homebrew.casks = [ name ];
    };
    description = "Add a homebrew cask";
    tests."adds firefox" = {
      args.name = "firefox";
      expected = { homebrew.casks = [ "firefox" ]; };
    };
  };

  lib.setDefault = {
    type = lib.types.functionTo (lib.types.functionTo (lib.types.functionTo lib.types.attrs));
    fn = domain: key: value: {
      system.defaults.${domain}.${key} = value;
    };
    description = "Set a macOS default";
    tests."sets dock autohide" = {
      args = { domain = "dock"; key = "autohide"; value = true; };
      expected = { system.defaults.dock.autohide = true; };
    };
  };
}
