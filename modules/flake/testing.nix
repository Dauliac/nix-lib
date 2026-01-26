# nlib.testing options
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.nlib.testing.backend = mkOption {
    type = types.enum [
      "nix-unit"
      "nixt"
      "nixtest"
      "runTests"
    ];
    default = "nix-unit";
    description = "Test framework backend to use";
  };
}
