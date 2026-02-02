# system-manager adapter definition
{ lib, ... }:
{
  config.nlib.adapterDefs.system-manager = lib.mkDefault {
    namespace = "system";
    hasBuiltinLib = false;
    collector = {
      configPath = [ "systemConfigs" ];
      # system-manager sets hostPlatform as a string directly
      systemPath = [
        "config"
        "nixpkgs"
        "hostPlatform"
      ];
    };
    nestedSystems = [ ];
  };
}
