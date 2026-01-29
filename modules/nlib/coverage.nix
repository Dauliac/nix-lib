# nlib.coverage
{ lib, ... }:
{
  options.nlib.coverage.threshold = lib.mkOption {
    type = lib.types.ints.between 0 100;
    default = 100;
    description = "Minimum test coverage percentage required (0 = disabled)";
  };
}
