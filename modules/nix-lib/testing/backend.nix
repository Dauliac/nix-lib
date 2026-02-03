# nix-lib.testing.backend
{ lib, ... }:
{
  options.nix-lib.testing.backend = lib.mkOption {
    type = lib.types.enum [
      "nix-unit"
      "nixt"
      "nixtest"
      "runTests"
    ];
    default = "nix-unit";
    description = "Test framework backend to use";
  };
}
