# Collector tests - BDD style flake-parts module
#
# Tests check structure, not specific functions (resilient to example changes)
# Tests are pure and don't depend on flake module evaluation in sandbox
#
# Note: These tests use flake.tests instead of perSystem.nix-unit.tests because
# the tests flake doesn't import nix-unit module (sandbox incompatibility with get-flake)
{ lib, config, ... }:
let
  flakeLib = config.flake.lib;
  # Pre-evaluate all expressions NOW at flake eval time
  # Convert to pure data that nix-unit can serialize
  results = {
    nixosNonEmpty = lib.hasAttr "nixos" flakeLib && (flakeLib.nixos or { }) != { };
    homeNonEmpty = lib.hasAttr "home" flakeLib && (flakeLib.home or { }) != { };
    vimNonEmpty = lib.hasAttr "vim" flakeLib && (flakeLib.vim or { }) != { };
    systemNonEmpty = lib.hasAttr "system" flakeLib && (flakeLib.system or { }) != { };
    darwinNonEmpty = lib.hasAttr "darwin" flakeLib && (flakeLib.darwin or { }) != { };
    wrappersNonEmpty = lib.hasAttr "wrappers" flakeLib && (flakeLib.wrappers or { }) != { };
    flakeNonEmpty = lib.hasAttr "flake" flakeLib && (flakeLib.flake or { }) != { };
    nixLibNonEmpty = lib.hasAttr "nix-lib" flakeLib && (flakeLib.nix-lib or { }) != { };
    nixosHomeNonEmpty =
      lib.hasAttr "home" (flakeLib.nixos or { }) && (flakeLib.nixos.home or { }) != { };
    nixosHomeVimNonEmpty =
      lib.hasAttr "vim" (flakeLib.nixos.home or { }) && (flakeLib.nixos.home.vim or { }) != { };
    homeVimNonEmpty = lib.hasAttr "vim" (flakeLib.home or { }) && (flakeLib.home.vim or { }) != { };
  };
in
{
  # Use flake.tests for manual nix-unit execution
  # Run with: nix-unit --flake ./tests#tests
  # Note: nix-unit requires test names to start with "test"
  flake.tests = {
    "test_collectors_flakeLib_nixos_not_empty" = {
      expr = results.nixosNonEmpty;
      expected = true;
    };
    "test_collectors_flakeLib_home_not_empty" = {
      expr = results.homeNonEmpty;
      expected = true;
    };
    "test_collectors_flakeLib_vim_not_empty" = {
      expr = results.vimNonEmpty;
      expected = true;
    };
    "test_collectors_flakeLib_system_not_empty" = {
      expr = results.systemNonEmpty;
      expected = true;
    };
    "test_collectors_flakeLib_darwin_not_empty" = {
      expr = results.darwinNonEmpty;
      expected = true;
    };
    "test_collectors_flakeLib_wrappers_not_empty" = {
      expr = results.wrappersNonEmpty;
      expected = true;
    };
    "test_collectors_flakeLib_flake_not_empty" = {
      expr = results.flakeNonEmpty;
      expected = true;
    };
    "test_collectors_flakeLib_nix_lib_not_empty" = {
      expr = results.nixLibNonEmpty;
      expected = true;
    };
    "test_collectors_nested_nixosHome_not_empty" = {
      expr = results.nixosHomeNonEmpty;
      expected = true;
    };
    "test_collectors_nested_nixosHomeVim_not_empty" = {
      expr = results.nixosHomeVimNonEmpty;
      expected = true;
    };
    "test_collectors_nested_homeVim_not_empty" = {
      expr = results.homeVimNonEmpty;
      expected = true;
    };
  };
}
