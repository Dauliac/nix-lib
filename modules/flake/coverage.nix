# nlib.coverage options
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.nlib.coverage.threshold = mkOption {
    type = types.ints.between 0 100;
    default = 100;
    description = "Minimum test coverage percentage required (0 = disabled)";
  };
}
