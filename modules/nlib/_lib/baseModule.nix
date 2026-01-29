# Base module for nlib lib definitions
#
# Defines the internal _nlibMeta option used to collect test metadata.
# This module is automatically included in all lib evaluations.
{ lib, ... }:
{
  # Note: options.lib.* are defined by mkLibOption, not here
  # We only define _nlibMeta for collecting test metadata

  options._nlibMeta = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          fn = lib.mkOption { type = lib.types.unspecified; };
          description = lib.mkOption { type = lib.types.str; };
          type = lib.mkOption { type = lib.types.unspecified; };
          tests = lib.mkOption {
            type = lib.types.lazyAttrsOf lib.types.unspecified;
            default = { };
          };
        };
      }
    );
    default = { };
    internal = true;
    description = "Internal metadata for test extraction";
  };
}
