# nlib.enable
{ lib, ... }:
{
  options.nlib.enable = lib.mkEnableOption "nlib library definitions";
}
