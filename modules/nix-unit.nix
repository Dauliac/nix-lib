# nix-unit integration
#
# Imports the nix-unit flake-parts module and configures it to work with nlib's test system.
# Tests defined via nlib.lib.*.tests are automatically converted and run by nix-unit.
{ inputs, ... }:
{
  imports = [
    inputs.nix-unit.modules.flake.default
  ];

  # nix-unit configuration
  perSystem =
    { system, ... }:
    {
      nix-unit.package = inputs.nix-unit.packages.${system}.default;
      # Pass all flake inputs + nix-unit's own inputs for offline sandbox evaluation
      # This ensures transitive dependencies (like nix-unit's flake-parts) are available
      nix-unit.inputs = inputs.nix-unit.inputs // inputs;
    };
}
