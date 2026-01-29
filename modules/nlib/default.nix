# nlib shared options
{ ... }:
{
  imports = [
    ./enable.nix
    ./namespace.nix
    ./testing.nix
    ./coverage.nix
    ./libs.nix
  ];
}
