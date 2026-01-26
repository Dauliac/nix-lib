# nlib.collectors (flake-only)
{ lib, config, ... }:
{
  options.nlib.collectors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.lazyAttrsOf lib.types.unspecified));
    default = { };
    description = "Functions to collect libs from other sources (nixos, home-manager, etc).";
  };

  config.nlib.collectors = {
    nixos =
      cfg:
      lib.foldl' (acc: name: acc // (cfg.flake.nixosConfigurations.${name}.config.nlib._libs or { }))
        { }
        (lib.attrNames (cfg.flake.nixosConfigurations or { }));

    home =
      cfg:
      lib.foldl' (acc: name: acc // (cfg.flake.homeConfigurations.${name}.config.nlib._libs or { }))
        { }
        (lib.attrNames (cfg.flake.homeConfigurations or { }));
  };
}
