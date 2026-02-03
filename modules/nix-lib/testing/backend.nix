# nix-lib.testing.backend
{ lib, ... }:
{
  options.nix-lib.testing.backend = lib.mkOption {
    type = lib.types.enum [
      "nix-unit"
      "nixt"
      "nixtest"
      "runTests"
      "nix-tests"
      "namaka"
    ];
    default = "nix-unit";
    description = ''
      Test framework backend to use for generating test output.

      Available backends:
      - `nix-unit` - nix-community/nix-unit (default, recommended)
      - `nixt` - TypeScript-based testing with describe/it blocks
      - `nixtest` - jetify-com/nixtest, pure Nix, no nixpkgs dependency
      - `runTests` - nixpkgs lib.debug.runTests format
      - `nix-tests` - danielefongo/nix-tests with helpers API
      - `namaka` - nix-community/namaka snapshot testing
    '';
  };
}
