# nix-lib.testing.outputPath
{ lib, ... }:
{
  options.nix-lib.testing.outputPath = lib.mkOption {
    type = lib.types.str;
    default = "test-results.xml";
    description = "Output file path for JUnit XML reports";
  };
}
