# Adapter tests - BDD style flake-parts module
#
# Tests check structure, not specific functions (resilient to example changes)
# System-dependent tests use perSystem.nix-unit.tests (flake-parts pattern)
#
# Note: nix-unit requires test names to start with "test"
{ lib, config, ... }:
let
  flakeLib = config.flake.lib;

  hasNonEmpty = attr: set: lib.hasAttr attr set && (set.${attr} or { }) != { };
  hasFunction = set: lib.any lib.isFunction (lib.attrValues set);

  # Flake-level results (no system dependency)
  flakeResults = {
    nixosHasFunc = hasFunction (flakeLib.nixos or { });
    homeHasFunc = hasFunction (flakeLib.home or { });
    vimHasFunc = hasFunction (flakeLib.vim or { });
    flakeHasFunc = hasFunction (flakeLib.flake or { });
  };
in
{
  # Flake-level tests (system-agnostic)
  flake.tests = {
    "test_adapters_functions_nixos_has_funcs" = {
      expr = flakeResults.nixosHasFunc;
      expected = true;
    };
    "test_adapters_functions_home_has_funcs" = {
      expr = flakeResults.homeHasFunc;
      expected = true;
    };
    "test_adapters_functions_vim_has_funcs" = {
      expr = flakeResults.vimHasFunc;
      expected = true;
    };
    "test_adapters_functions_flake_has_funcs" = {
      expr = flakeResults.flakeHasFunc;
      expected = true;
    };
  };

  # System-dependent tests use perSystem
  perSystem =
    { config, ... }:
    let
      systemLib = config.legacyPackages.lib or { };

      # Pre-evaluate system-specific expressions
      results = {
        lpNixosNonEmpty = hasNonEmpty "nixos" systemLib;
        lpHomeNonEmpty = hasNonEmpty "home" systemLib;
        lpVimNonEmpty = hasNonEmpty "vim" systemLib;
        lpSystemNonEmpty = hasNonEmpty "system" systemLib;
        lpNixosHomeNonEmpty = hasNonEmpty "home" (systemLib.nixos or { });
        lpNixosHomeVimNonEmpty = hasNonEmpty "vim" (systemLib.nixos.home or { });
        lpHomeVimNonEmpty = hasNonEmpty "vim" (systemLib.home or { });
      };
    in
    {
      nix-unit.tests = {
        "test_adapters_legacyPkgs_nixos_not_empty" = {
          expr = results.lpNixosNonEmpty;
          expected = true;
        };
        "test_adapters_legacyPkgs_home_not_empty" = {
          expr = results.lpHomeNonEmpty;
          expected = true;
        };
        "test_adapters_legacyPkgs_vim_not_empty" = {
          expr = results.lpVimNonEmpty;
          expected = true;
        };
        "test_adapters_legacyPkgs_system_not_empty" = {
          expr = results.lpSystemNonEmpty;
          expected = true;
        };
        "test_adapters_legacyPkgs_nixosHome_not_empty" = {
          expr = results.lpNixosHomeNonEmpty;
          expected = true;
        };
        "test_adapters_legacyPkgs_nixosHomeVim_not_empty" = {
          expr = results.lpNixosHomeVimNonEmpty;
          expected = true;
        };
        "test_adapters_legacyPkgs_homeVim_not_empty" = {
          expr = results.lpHomeVimNonEmpty;
          expected = true;
        };
      };
    };
}
