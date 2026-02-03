# Example: Defining libs in nix-darwin module
#
# Define at: nix-lib.lib.<name>
# Use at: config.lib.<name> (within darwin config)
# Output at: flake.lib.darwin.<name> (collected at flake-parts level)
#
# Usage in darwinConfigurations:
#   modules = [
#     nix-lib.darwinModules.default
#     {
#       nix-lib.enable = true;
#       nix-lib.lib.myHelper = { ... };
#     }
#   ];
#
{ lib, ... }:
{
  nix-lib.enable = true;

  # Nix-darwin specific lib functions
  nix-lib.lib.mkBrewPackage = {
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

  nix-lib.lib.mkBrewCask = {
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

  nix-lib.lib.setDefault = {
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
