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
{ lib, config, ... }:
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
    type = lib.types.functionTo (lib.types.functionTo (lib.types.functionTo lib.types.attrs));
    fn = domain: key: value: {
      system.defaults.${domain}.${key} = value;
    };
    description = "Set a macOS default";
    tests."sets dock autohide" = {
      args = {
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
  # Usage: Real configs using the libs (for e2e testing)
  # ============================================================

  imports = [
    # Use lib to add homebrew packages
    (config.lib.mkBrewPackage "curl")
    (config.lib.mkBrewPackage "jq")
    (config.lib.mkBrewPackage "ripgrep")

    # Use lib to add homebrew casks
    (config.lib.mkBrewCask "iterm2")
    (config.lib.mkBrewCask "visual-studio-code")

    # Use lib to set macOS defaults
    (config.lib.setDefault "dock" "autohide" true)
    (config.lib.setDefault "dock" "show-recents" false)
    (config.lib.setDefault "finder" "ShowPathbar" true)
  ];
}
