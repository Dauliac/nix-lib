# nix-lib.testing
{ lib, ... }:
{
  options.nix-lib.testing = {
    backend = lib.mkOption {
      type = lib.types.enum [
        "nix-unit"
        "nixt"
        "nixtest"
        "runTests"
      ];
      default = "nix-unit";
      description = "Test framework backend to use";
    };

    reporter = lib.mkOption {
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

    outputPath = lib.mkOption {
      type = lib.types.str;
      default = "test-results.xml";
      description = "Output file path for JUnit XML reports";
    };
  };
}
