# nix-lib.docs.package (perSystem)
#
# Documentation derivation(s) containing markdown for lib functions.
# Uses tree-sitter-nix to extract fn bodies from source files at build time.
#
# Supports multi-page output via nix-lib.docs.pages — each page generates
# a separate .md file with its own header, heading level, and metadata.
# When pages is empty, falls back to a single docs.md using top-level options.
#
{ lib, config, ... }:
let
  libDefTypeModule = import ../_lib/libDefType.nix { inherit lib; };
  inherit (libDefTypeModule) flattenLibs libDefsToMeta;
  markdown = import ./_markdown.nix { inherit lib; };

  # Get flake-level lib metadata, prefixed with "flake."
  rawFlakeLibsMeta = config.nix-lib._flakeLibsMeta or { };
  flakeLibsMeta = lib.mapAttrs' (name: value: {
    name = "flake.${name}";
    inherit value;
  }) rawFlakeLibsMeta;

  # Get collected metadata from all module systems (keyed by namespace)
  collectedMeta = lib.mapAttrs (_: collector: collector config) (
    config.nix-lib.metaCollectors or { }
  );

  # Prefix each collected lib with its namespace: nixos.mkService, home.mkShell, etc.
  allCollectedMeta = lib.foldl' (
    acc: ns:
    let
      meta = collectedMeta.${ns};
    in
    acc
    // (lib.mapAttrs' (name: value: {
      name = "${ns}.${name}";
      inherit value;
    }) meta)
  ) { } (lib.attrNames collectedMeta);

  # All flake-level metadata (flake libs + collected from nixos/home/etc)
  allFlakeMeta = flakeLibsMeta // allCollectedMeta;

  # Page submodule type
  pageType = lib.types.submodule {
    options = {
      header = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Markdown content prepended before generated function docs.";
      };
      headingLevel = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Starting heading level for namespaces and functions.";
      };
      showIndex = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include function index.";
      };
      showTitle = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include title and lib count.";
      };
      metadata = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.unspecified);
        default = null;
        description = ''
          Custom metadata attrset for this page.
          When null (default), uses auto-collected libs from all scopes.
          Set this to inject metadata from a specific evaluation
          (e.g., NixOS container eval _libsMeta).
        '';
      };
    };
  };
in
{
  perSystem =
    {
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.nix-lib.docs;

      # Get per-system lib metadata
      perSystemLibDefs = flattenLibs "" (config.nix-lib.lib or { });
      perSystemLibsMeta = libDefsToMeta perSystemLibDefs (config.lib or { });

      # Default auto-collected metadata (all scopes merged)
      autoCollectedMeta = allFlakeMeta // perSystemLibsMeta;

      # Serialize metadata to JSON (without fn closures, with type as string)
      metaToJson =
        {
          meta,
          showTitle,
          showIndex,
          headingLevel,
        }:
        let
          cleanMeta = builtins.removeAttrs meta [ "__docsOptions" ];
          cleanTests =
            tests:
            lib.mapAttrs (
              _: t:
              builtins.removeAttrs t [ "check" ]
              // {
                assertions = map (a: builtins.removeAttrs a [ "check" ]) (t.assertions or [ ]);
              }
            ) tests;
          computeFnSignature =
            m:
            let
              fn = m.fn or null;
              fnArgs = if fn != null && builtins.isFunction fn then builtins.functionArgs fn else { };
              hasSetPattern = fnArgs != { };
              argNames = builtins.attrNames fnArgs;
              argEntries = map (name: if fnArgs.${name} then "${name} ? ..." else name) argNames;
            in
            if hasSetPattern then "{ ${lib.concatStringsSep ", " argEntries} }" else null;
          serializable = lib.mapAttrs (
            _: m:
            builtins.removeAttrs m [ "fn" ]
            // {
              fnSignature = computeFnSignature m;
              type =
                let
                  t = m.type or null;
                in
                if t == null then
                  null
                else if builtins.isString t then
                  t
                else if builtins.isAttrs t && t ? description then
                  t.description
                else
                  builtins.toString t;
              tests = cleanTests (m.tests or { });
            }
          ) cleanMeta;
        in
        serializable
        // {
          __options = {
            inherit showTitle showIndex headingLevel;
          };
        };

      pythonWithTreeSitter = pkgs.python3.withPackages (ps: [ ps.tree-sitter ]);
      treeSitterNix = pkgs.tree-sitter-grammars.tree-sitter-nix;
      generateScript = ./_generate-docs.py;

      # Build a single docs page from a page config
      buildPage =
        name: pageCfg:
        let
          pageMeta = if pageCfg.metadata != null then pageCfg.metadata else autoCollectedMeta;
          pageJson = builtins.toJSON (metaToJson {
            meta = pageMeta;
            inherit (pageCfg) showTitle showIndex headingLevel;
          });
          headerFile = pkgs.writeText "nix-lib-header-${name}.md" pageCfg.header;
        in
        if cfg.src != null then
          pkgs.runCommand "nix-lib-page-${name}"
            {
              nativeBuildInputs = [ pythonWithTreeSitter ];
              passAsFile = [ "metadata" ];
              metadata = pageJson;
            }
            ''
              python3 ${generateScript} \
                ${treeSitterNix}/parser \
                "$metadataPath" \
                ${cfg.src} \
                $TMPDIR/generated.md
              cat ${headerFile} $TMPDIR/generated.md > $out
            ''
        else
          pkgs.writeText "nix-lib-page-${name}" (
            pageCfg.header
            + markdown.generateMarkdown (
              pageMeta
              // {
                __docsOptions = {
                  inherit (pageCfg) showTitle showIndex headingLevel;
                };
              }
            )
          );

      # Effective pages: if pages is set, use it; otherwise build a default page
      effectivePages =
        if cfg.pages != { } then
          cfg.pages
        else
          {
            docs = {
              inherit (cfg)
                header
                headingLevel
                showIndex
                showTitle
                ;
              metadata = null;
            };
          };

      # Build multi-page output
      pageDerivations = lib.mapAttrs buildPage effectivePages;

      docsPackage = pkgs.runCommand "nix-lib-docs" { } (
        ''
          mkdir -p $out
        ''
        + lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: drv: "cp ${drv} $out/${name}.md") pageDerivations
        )
      );
    in
    {
      options.nix-lib.docs = {
        package = lib.mkOption {
          type = lib.types.package;
          default = docsPackage;
          description = ''
            Markdown documentation package for all defined libs.

            When `pages` is empty, outputs a single `docs.md`.
            When `pages` is set, outputs one `<name>.md` per page.
            When `src` is set, function bodies are automatically extracted
            from source files using tree-sitter.
          '';
        };

        src = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Source root directory for fn body extraction.

            Set this to `self` (the flake source) to enable automatic
            extraction of function implementation bodies in the generated docs.

            Example: `nix-lib.docs.src = self;`
          '';
        };

        pages = lib.mkOption {
          type = lib.types.attrsOf pageType;
          default = { };
          description = ''
            Multi-page documentation output. Each key becomes a `<key>.md` file.

            When empty (default), a single `docs.md` is generated using the
            top-level `header`, `headingLevel`, `showIndex`, `showTitle` options.

            Each page can have its own header, heading level, and metadata source.
            Set `metadata` to inject libs from a specific evaluation scope
            (e.g., NixOS container, deploy modules).

            Example:
            ```nix
            nix-lib.docs.pages = {
              flake-parts = {
                header = "Functions for flake-parts consumers...";
                headingLevel = 2;
              };
              container = {
                header = "Functions inside NixOS container eval...";
                headingLevel = 2;
                metadata = containerLibsMeta;
              };
            };
            ```
          '';
        };

        # Legacy top-level options (used when pages is empty)
        showIndex = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Include function index (legacy, used when `pages` is empty).";
        };

        showTitle = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Include title and lib count (legacy, used when `pages` is empty).";
        };

        headingLevel = lib.mkOption {
          type = lib.types.int;
          default = 3;
          description = "Starting heading level (legacy, used when `pages` is empty).";
        };

        header = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Header markdown (legacy, used when `pages` is empty).";
        };
      };
    };
}
