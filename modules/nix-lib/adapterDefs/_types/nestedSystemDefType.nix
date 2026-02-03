# Nested system definition type
#
# Defines how to extract libs from a nested module system.
# Example: NixOS extracting libs from home-manager users.
#
{ lib }:
lib.types.submodule {
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      description = ''
        Namespace for nested libs in config.lib.<name>.

        Example: "home" makes home-manager libs available at config.lib.home.*
      '';
      example = "home";
    };

    path = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        Path to nested config in parent options.

        Example: [ "home-manager" "users" ] for NixOS home-manager integration
      '';
      example = [
        "home-manager"
        "users"
      ];
    };

    multi = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether multiple instances exist at the path.

        Set to true for paths like home-manager.users.<name> where
        libs should be collected from all user configurations.
      '';
    };

    nestedPath = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Deep path inside each multi instance.

        For home-manager -> nixvim, this is [ "programs" "nixvim" ]
        to reach users.<name>.programs.nixvim
      '';
      example = [
        "programs"
        "nixvim"
      ];
    };
  };
}
