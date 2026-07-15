# Partitions — isolate nixpkgs from consumer lock file.
#
# The main evaluation uses only nixpkgs-lib (lightweight, lib-only).
# Pkgs-dependent outputs (packages, apps) come from the "dev" partition,
# which has full nixpkgs via extraInputsFlake.
#
# Consumers never fetch full nixpkgs from nix-lib — they provide their own.
{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.partitions
  ];

  partitionedAttrs = {
    packages = "dev";
    apps = "dev";
    checks = "dev";
    devShells = "dev";
    formatter = "dev";
  };

  partitions.dev = {
    extraInputsFlake = ./_dev;
    module = ./_dev/module.nix;
  };
}
