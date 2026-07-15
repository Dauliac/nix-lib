# Pkgs partition module — imports pkgs-dependent project modules.
# These are evaluated separately from the pure main evaluation.
{ ... }:
{
  imports = [
    ./nix-let-fn-linter.nix
    ./e2e-tests.nix
  ];
}
