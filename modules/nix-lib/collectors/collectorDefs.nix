# nix-lib.collectorDefs
#
# Manual collector definitions for custom module systems.
# Built-in collectors are auto-generated from adapterDefs.
#
{ lib, config, ... }:
let
  cfg = config.nix-lib;
  adapterDefs = cfg.adapterDefs or { };

  # Collector definition submodule type (legacy, for backwards compat)
  collectorDefType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable this collector";
        };

        pathType = lib.mkOption {
          type = lib.types.enum [
            "flat"
            "perSystem"
          ];
          default = "flat";
          description = ''
            Collection strategy:
            - flat: Traverse flake.<configPath>.<name>.config.nix-lib.<attr>
            - perSystem: Traverse flake.legacyPackages.<system>.<configPath>
          '';
        };

        configPath = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Path to configuration set within flake outputs";
          example = [ "nixosConfigurations" ];
        };

        systemPath = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Path to extract system from configuration";
          example = [
            "config"
            "nixpkgs"
            "hostPlatform"
            "system"
          ];
        };

        namespace = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Output namespace in legacyPackages.<sys>.lib.<namespace>";
        };

        description = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Documentation for this collector";
        };
      };
    }
  );

  # Build collector defs from adapterDefs
  adapterCollectorDefs = lib.mapAttrs (
    name: def:
    lib.mkDefault {
      enable = def.collector.enable or true;
      pathType = if def.collector.configPath or [ ] == [ ] then "perSystem" else "flat";
      configPath = def.collector.configPath or [ ];
      systemPath = def.collector.systemPath or [ ];
      namespace = def.namespace or name;
      description = "${name} configuration libs";
    }
  ) (lib.filterAttrs (_: def: def.enable or true) adapterDefs);
in
{
  options.nix-lib.collectorDefs = lib.mkOption {
    type = lib.types.attrsOf collectorDefType;
    default = { };
    description = ''
      Collector definitions. Each collector specifies how to gather libs
      from a module system and export them to legacyPackages.<sys>.lib.<namespace>.

      Example:
      ```nix
      nix-lib.collectorDefs.mySystem = {
        pathType = "flat";
        configPath = [ "myConfigurations" ];
        systemPath = [ "config" "nixpkgs" "system" ];
        namespace = "my";
        description = "Custom module system libs";
      };
      ```
    '';
  };

  # Built-in collectors from adapterDefs
  config.nix-lib.collectorDefs = adapterCollectorDefs;
}
