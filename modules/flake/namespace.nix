# nlib.namespace option
{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.nlib;
in
{
  options.nlib.namespace = mkOption {
    type = types.str;
    default = "lib";
    description = "Namespace under flake.lib where functions are exposed";
    example = "myproject";
  };
}
