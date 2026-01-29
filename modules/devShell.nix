# Development shell configuration
{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          inputs.nix-unit.packages.${system}.default
        ];
      };
    };
}
