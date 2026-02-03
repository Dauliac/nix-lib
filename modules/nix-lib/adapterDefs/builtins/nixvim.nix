# nixvim adapter definition
{ lib, ... }:
{
  config.nix-lib.adapterDefs.nixvim = lib.mkDefault {
    namespace = "vim";
    hasBuiltinLib = false;
    collector = {
      configPath = [ "nixvimConfigurations" ];
      systemPath = [
        "config"
        "nixpkgs"
        "pkgs"
        "system"
      ];
    };
    nestedSystems = [ ];
  };
}
