# nix-lib.coverage
{ lib, ... }:
{
  options.nix-lib.coverage.threshold = lib.mkOption {
    type = lib.types.ints.between 0 100;
    default = 100;
    description = "Minimum test coverage percentage required (0 = disabled)";
  };
}
