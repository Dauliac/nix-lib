# nlib.namespace
{ lib, ... }:
{
  options.nlib.namespace = lib.mkOption {
    type = lib.types.str;
    default = "lib";
    description = "Namespace for this module system's libs";
    example = "mymodule.lib";
  };
}
