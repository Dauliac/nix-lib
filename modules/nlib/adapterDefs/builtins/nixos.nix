# NixOS adapter definition
{ lib, ... }:
{
  config.nlib.adapterDefs.nixos = lib.mkDefault {
    namespace = "nixos";
    hasBuiltinLib = true;
    collector = {
      configPath = [ "nixosConfigurations" ];
      # NixOS uses pkgs.hostPlatform.system (not config.nixpkgs.hostPlatform)
      # when system is passed to nixosSystem instead of setting hostPlatform option
      systemPath = [
        "pkgs"
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
