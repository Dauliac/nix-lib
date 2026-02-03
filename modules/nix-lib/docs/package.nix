# nix-lib.docs.package (perSystem)
#
# The documentation derivation containing docs.md.
#
{ lib, config, ... }:
let
  libDefTypeModule = import ../_lib/libDefType.nix { inherit lib; };
  inherit (libDefTypeModule) flattenLibs libDefsToMeta;
  markdown = import ./_markdown.nix { inherit lib; };

  # Get flake-level lib metadata
  flakeLibsMeta = config.nix-lib._flakeLibsMeta or { };

  # Get collected metadata from all module systems
  collectedMeta = lib.mapAttrs (_: collector: collector config) (
    config.nix-lib.metaCollectors or { }
  );

  # Flatten all collected metadata
  allCollectedMeta = lib.foldl' (acc: meta: acc // meta) { } (lib.attrValues collectedMeta);

  # All flake-level metadata (flake libs + collected from nixos/home/etc)
  allFlakeMeta = flakeLibsMeta // allCollectedMeta;
in
{
  perSystem =
    {
      pkgs,
      config,
      ...
    }:
    let
      # Get per-system lib metadata
      perSystemLibDefs = flattenLibs "" (config.nix-lib.lib or { });
      perSystemLibsMeta = libDefsToMeta perSystemLibDefs (config.lib or { });

      # Merge flake metadata (from closure) with per-system metadata
      allLibsMeta = allFlakeMeta // perSystemLibsMeta;

      # Create the derivation
      docsDerivation = pkgs.writeTextFile {
        name = "nix-lib-docs";
        text = markdown.generateMarkdown allLibsMeta;
        destination = "/docs.md";
      };
    in
    {
      options.nix-lib.docs.package = lib.mkOption {
        type = lib.types.package;
        default = docsDerivation;
        description = ''
          Markdown documentation package for all defined libs.

          The output contains a `docs.md` file with all lib definitions.
        '';
      };
    };
}
