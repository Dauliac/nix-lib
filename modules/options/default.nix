# nlib shared options
{ ... }:
{
  imports = [
    ./enable.nix
    ./namespace.nix
    ./perLib.nix
    ./testing.nix
    ./coverage.nix
    ./_libs.nix
  ];
}
