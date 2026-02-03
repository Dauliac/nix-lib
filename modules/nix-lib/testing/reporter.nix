# nix-lib.testing.reporter
{ lib, ... }:
{
  options.nix-lib.testing.reporter = lib.mkOption {
    type = lib.types.enum [
      "default"
      "junit"
      "dot"
    ];
    default = "default";
    description = ''
      Test reporter format.
      - default: Human-readable output
      - junit: JUnit XML format (for CI/CD integration)
      - dot: Minimal dot output
    '';
  };
}
