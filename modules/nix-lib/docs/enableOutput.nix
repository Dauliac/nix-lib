# nix-lib.docs.enableOutput (perSystem)
#
# Whether to export the docs package as packages.nix-lib-docs.
#
{ lib, ... }:
{
  perSystem =
    { config, ... }:
    let
      cfg = config.nix-lib.docs;
    in
    {
      options.nix-lib.docs.enableOutput = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to export the docs package as `packages.nix-lib-docs`.

          When enabled, you can build with:
          ```
          nix build .#nix-lib-docs
          ```
        '';
      };

      # Export as package when enabled
      config.packages = lib.mkIf cfg.enableOutput {
        nix-lib-docs = cfg.package;
      };
    };
}
