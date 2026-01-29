# treefmt configuration for code formatting and linting
{ inputs, ... }:
{
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";

      programs = {
        # Nix formatting
        nixfmt.enable = true;

        # Dead code detection
        deadnix.enable = true;

        # Static analysis
        statix.enable = true;
      };
    };
  };
}
