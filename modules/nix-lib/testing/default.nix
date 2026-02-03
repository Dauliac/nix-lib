# nix-lib.testing - Test configuration options
#
# Options for configuring the test framework backend and reporting.
#
{ ... }:
{
  imports = [
    ./backend.nix
    ./reporter.nix
    ./outputPath.nix
  ];
}
