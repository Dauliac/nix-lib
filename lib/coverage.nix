# Coverage calculation for nlib
#
# Calculates test coverage metrics for library functions
{ lib }:
let
  inherit (lib) length attrNames attrValues;
in
{
  # Calculate coverage statistics
  calculate =
    libs:
    let
      libList = attrValues libs;
      total = length libList;
      withTests = length (builtins.filter (l: (l.tests or { }) != { }) libList);
      percent = if total == 0 then 100 else (withTests * 100) / total;
    in
    {
      inherit total withTests percent;
      allTested = withTests == total;
    };
}
