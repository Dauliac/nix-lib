# nix-lib.enable
{ lib, ... }:
{
  options.nix-lib.enable = lib.mkEnableOption "nix-lib library definitions";
}
