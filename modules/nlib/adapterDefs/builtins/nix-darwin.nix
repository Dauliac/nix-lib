# nix-darwin adapter definition
{ lib, ... }:
{
  config.nlib.adapterDefs.nix-darwin = lib.mkDefault {
    namespace = "darwin";
    hasBuiltinLib = false;
    collector = {
      configPath = [ "darwinConfigurations" ];
      systemPath = [
        "config"
        "nixpkgs"
        "hostPlatform"
        "system"
      ];
    };
    nestedSystems = [
      {
        name = "home";
        path = [
          "home-manager"
          "users"
        ];
        multi = true;
      }
      {
        name = "vim";
        path = [
          "home-manager"
          "users"
        ];
        multi = true;
        nestedPath = [
          "programs"
          "nixvim"
        ];
      }
    ];
  };
}
