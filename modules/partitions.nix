# Partitions — separate pkgs-dependent outputs from pure evaluation.
#
# The main flake evaluation only loads pure modules.
# Pkgs-dependent outputs (packages, apps) come from the "pkgs" partition,
# which adds nix-let-fn-linter and e2e-tests modules.
#
# This means accessing nix-lib.flakeModules.* or nix-lib.nixosModules.*
# never instantiates pkgs.
{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.partitions
  ];

  partitionedAttrs = {
    packages = "pkgs";
    apps = "pkgs";
  };

  partitions.pkgs.module = ./_pkgs/module.nix;
}
