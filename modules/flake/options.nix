# nlib module options
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.nlib = {
    namespace = mkOption {
      type = types.str;
      default = "lib";
      description = "Namespace under flake.lib where functions are exposed";
      example = "myproject";
    };

    libs = mkOption {
      type = types.lazyAttrsOf types.unspecified;
      default = { };
      description = "Library functions created with mkLib";
    };

    testing = {
      backend = mkOption {
        type = types.enum [
          "nix-unit"
          "nixt"
          "nixtest"
          "runTests"
        ];
        default = "nix-unit";
        description = "Test framework backend to use";
      };
    };

    coverage = {
      threshold = mkOption {
        type = types.ints.between 0 100;
        default = 100;
        description = "Minimum test coverage percentage required (0 = disabled)";
      };
    };
  };
}
