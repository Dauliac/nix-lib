# Pkgs partition module — imports pkgs-dependent project modules.
# These are evaluated separately from the pure main evaluation.
{ ... }:
{
  imports = [
    ./e2e-tests.nix
  ];
}
