# Example: Defining libs in nix-darwin module
#
# Define at: nlib.lib.<name>
# Use at: config.lib.<name> (within darwin config)
# Output at: flake.lib.darwin.<name> (collected at flake-parts level)
#
# Usage in darwinConfigurations:
#   modules = [
#     nlib.darwinModules.default
#     {
#       nlib.enable = true;
#       nlib.lib.myHelper = { ... };
#     }
#   ];
#
{ lib, ... }:
{
  nlib.enable = true;

  # Nix-darwin specific lib functions
  nlib.lib.mkBrewPackage = {
    type = lib.types.functionTo lib.types.attrs;
    fn = name: {
      homebrew.brews = [ name ];
    };
    description = "Add a homebrew package";
    tests."adds wget" = {
      args.name = "wget";
      expected = {
        homebrew.brews = [ "wget" ];
      };
    };
  };

  nlib.lib.mkBrewCask = {
    type = lib.types.functionTo lib.types.attrs;
    fn = name: {
      homebrew.casks = [ name ];
    };
    description = "Add a homebrew cask";
    tests."adds firefox" = {
      args.name = "firefox";
      expected = {
        homebrew.casks = [ "firefox" ];
      };
    };
  };

  nlib.lib.setDefault = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        domain,
        key,
        value,
      }:
      {
        system.defaults.${domain}.${key} = value;
      };
    description = "Set a macOS default";
    tests."sets dock autohide" = {
      args.a = {
        domain = "dock";
        key = "autohide";
        value = true;
      };
      expected = {
        system.defaults.dock.autohide = true;
      };
    };
  };

  # ============================================================
  # Usage Example (in a separate module imported after this one):
  # ============================================================
  #
  # { config, ... }: {
  #   imports = [
  #     (config.lib.mkBrewPackage "curl")
  #     (config.lib.mkBrewCask "iterm2")
  #     (config.lib.setDefault { domain = "dock"; key = "autohide"; value = true; })
  #   ];
  # }
}
