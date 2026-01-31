# nlib.collectors (flake-only)
{ lib, ... }:
{
  options.nlib.collectors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.lazyAttrsOf lib.types.unspecified));
    default = { };
    description = "Functions to collect libs from other sources (nixos, home-manager, etc).";
  };

  options.nlib.metaCollectors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.lazyAttrsOf lib.types.unspecified));
    default = { };
    internal = true;
    description = "Functions to collect lib metadata from other sources.";
  };

  # Collectors use _fns which includes both own libs and nested propagated libs
  config.nlib.collectors = {
    nixos =
      cfg:
      lib.foldl' (
        acc: name: acc // (cfg.flake.nixosConfigurations.${name}.config.nlib._fns or { })
      ) { } (lib.attrNames (cfg.flake.nixosConfigurations or { }));

    home =
      cfg:
      lib.foldl' (acc: name: acc // (cfg.flake.homeConfigurations.${name}.config.nlib._fns or { })) { } (
        lib.attrNames (cfg.flake.homeConfigurations or { })
      );

    darwin =
      cfg:
      lib.foldl' (
        acc: name: acc // (cfg.flake.darwinConfigurations.${name}.config.nlib._fns or { })
      ) { } (lib.attrNames (cfg.flake.darwinConfigurations or { }));

    vim =
      cfg:
      lib.foldl' (
        acc: name: acc // (cfg.flake.nixvimConfigurations.${name}.config.nlib._fns or { })
      ) { } (lib.attrNames (cfg.flake.nixvimConfigurations or { }));

    system =
      cfg:
      lib.foldl' (acc: name: acc // (cfg.flake.systemConfigs.${name}.config.nlib._fns or { })) { } (
        lib.attrNames (cfg.flake.systemConfigs or { })
      );
  };

  config.nlib.metaCollectors = {
    nixos =
      cfg:
      lib.foldl' (
        acc: name: acc // (cfg.flake.nixosConfigurations.${name}.config.nlib._libsMeta or { })
      ) { } (lib.attrNames (cfg.flake.nixosConfigurations or { }));

    home =
      cfg:
      lib.foldl' (
        acc: name: acc // (cfg.flake.homeConfigurations.${name}.config.nlib._libsMeta or { })
      ) { } (lib.attrNames (cfg.flake.homeConfigurations or { }));

    darwin =
      cfg:
      lib.foldl' (
        acc: name: acc // (cfg.flake.darwinConfigurations.${name}.config.nlib._libsMeta or { })
      ) { } (lib.attrNames (cfg.flake.darwinConfigurations or { }));

    vim =
      cfg:
      lib.foldl' (
        acc: name: acc // (cfg.flake.nixvimConfigurations.${name}.config.nlib._libsMeta or { })
      ) { } (lib.attrNames (cfg.flake.nixvimConfigurations or { }));

    system =
      cfg:
      lib.foldl' (acc: name: acc // (cfg.flake.systemConfigs.${name}.config.nlib._libsMeta or { })) { } (
        lib.attrNames (cfg.flake.systemConfigs or { })
      );
  };
}
