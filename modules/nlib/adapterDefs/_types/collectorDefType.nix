# Collector configuration submodule
#
# Defines how to collect libs from a module system at flake level.
#
{ lib }:
lib.types.submodule {
  options = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable collector for this adapter";
    };

    configPath = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Path to configuration set within flake outputs";
      example = [ "nixosConfigurations" ];
    };

    systemPath = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Path to extract system from each configuration.

        Example: [ "config" "nixpkgs" "hostPlatform" "system" ] for NixOS
        The collector uses this to group libs by system in legacyPackages.
      '';
      example = [
        "config"
        "nixpkgs"
        "hostPlatform"
        "system"
      ];
    };
  };
}
