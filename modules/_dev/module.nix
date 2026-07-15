# Dev partition module — provides nixpkgs for building packages and apps.
# The main evaluation is pure (no pkgs); this partition adds the full
# nix-lib module set (docs, per-system libs) plus pkgs from nixpkgs.
{ inputs, ... }:
{
  imports = [
    ../nix-lib/_default.nix
    ../_pkgs/e2e-tests.nix
  ];

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = inputs.nixpkgs.legacyPackages.${system};
    };
}
