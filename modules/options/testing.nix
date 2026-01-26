# nlib.testing
{ lib, ... }:
{
  options.nlib.testing.backend = lib.mkOption {
    type = lib.types.enum [ "nix-unit" "nixt" "nixtest" "runTests" ];
    default = "nix-unit";
    description = "Test framework backend to use";
  };
}
