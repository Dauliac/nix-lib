# wrappers adapter definition
#
# Shared by both nix-wrapper-modules and Lassulus/wrappers
{ lib, ... }:
{
  config.nix-lib.adapterDefs.wrappers = lib.mkDefault {
    namespace = "wrappers";
    hasBuiltinLib = false;
    collector = {
      configPath = [ "wrapperConfigurations" ];
      # Wrappers may not have a standard system path, handled specially
      systemPath = [ ];
    };
    nestedSystems = [ ];
  };
}
