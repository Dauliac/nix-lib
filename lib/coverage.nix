# Coverage calculation for nlib
#
# Calculates test coverage metrics for library functions
#
# Libs can be either:
#   - Legacy format: { name, tests, fn, ... }
#   - New format: { _nlib = { name, tests, fn, ... }; ... }
{ lib }:
let
  inherit (lib) length attrValues;

  # Extract nlib metadata from lib definition (supports both formats)
  getMeta = def: def._nlib or def;
in
{
  # Calculate coverage statistics
  calculate =
    libs:
    let
      libList = attrValues libs;
      total = length libList;
      withTests = length (
        builtins.filter (l: ((getMeta l).tests or { }) != { }) libList
      );
      percent = if total == 0 then 100 else (withTests * 100) / total;
    in
    {
      inherit total withTests percent;
      allTested = withTests == total;
    };
}
