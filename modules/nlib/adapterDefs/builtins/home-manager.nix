# home-manager adapter definition
{ lib, ... }:
{
  config.nlib.adapterDefs.home-manager = lib.mkDefault {
    namespace = "home";
    hasBuiltinLib = true;
    collector = {
      configPath = [ "homeConfigurations" ];
      systemPath = [
        "pkgs"
        "system"
      ];
    };
    nestedSystems = [
      {
        name = "vim";
        path = [
          "programs"
          "nixvim"
        ];
        multi = false;
      }
    ];
  };
}
