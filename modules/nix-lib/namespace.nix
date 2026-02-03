# nix-lib.namespace
{ lib, ... }:
{
  options.nix-lib.namespace = lib.mkOption {
    type = lib.types.str;
    default = "lib";
    description = "Namespace for this module system's libs";
    example = "mymodule.lib";
  };
}
