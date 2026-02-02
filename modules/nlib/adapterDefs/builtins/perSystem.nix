# perSystem adapter definition
#
# For libs defined in flake-parts perSystem
{ lib, ... }:
{
  config.nlib.adapterDefs.perSystem = lib.mkDefault {
    namespace = "perSystem";
    hasBuiltinLib = false;
    collector = {
      # Special handling: collected from legacyPackages directly
      configPath = [ "nlib" ];
      # System is already known from legacyPackages.<sys>
      systemPath = [ ];
    };
    nestedSystems = [ ];
  };
}
