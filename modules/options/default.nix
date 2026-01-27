# nlib shared options
{ ... }:
{
  imports = [
    ./enable.nix
    ./namespace.nix
    ./testing.nix
    ./coverage.nix
    ./_libs.nix
  ];
}
