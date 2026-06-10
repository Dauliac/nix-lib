# nix-lib.docs.package (perSystem)
#
# The documentation derivation containing docs.md.
# Uses tree-sitter-nix to extract fn bodies from source files at build time.
#
{ lib, config, ... }:
let
  libDefTypeModule = import ../_lib/libDefType.nix { inherit lib; };
  inherit (libDefTypeModule) flattenLibs libDefsToMeta;
  markdown = import ./_markdown.nix { inherit lib; };

  # Get flake-level lib metadata, prefixed with "flake."
  rawFlakeLibsMeta = config.nix-lib._flakeLibsMeta or { };
  flakeLibsMeta = lib.mapAttrs' (
    name: value: { name = "flake.${name}"; inherit value; }
  ) rawFlakeLibsMeta;

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
    acc // (lib.mapAttrs' (name: value: { name = "${ns}.${name}"; inherit value; }) meta)
  ) { } (lib.attrNames collectedMeta);

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
      cfg = config.nix-lib.docs;

      # Get per-system lib metadata
      perSystemLibDefs = flattenLibs "" (config.nix-lib.lib or { });
      perSystemLibsMeta = libDefsToMeta perSystemLibDefs (config.lib or { });

      # Merge flake metadata (from closure) with per-system metadata
      allLibsMeta = allFlakeMeta // perSystemLibsMeta // {
        __docsOptions = {
          showIndex = cfg.showIndex;
          showTitle = cfg.showTitle;
          headingLevel = cfg.headingLevel;
        };
      };

      # Serialize metadata to JSON (without fn closures, with type as string)
      metaToJson =
        meta:
        let
          opts = meta.__docsOptions or { };
          cleanMeta = builtins.removeAttrs meta [ "__docsOptions" ];
          # Strip functions from test assertions for JSON serialization
          cleanTests =
            tests:
            lib.mapAttrs (
              _: t:
              builtins.removeAttrs t [ "check" ]
              // {
                assertions = map (a: builtins.removeAttrs a [ "check" ]) (t.assertions or [ ]);
              }
            ) tests;
          # Compute function signature from fn before stripping it
          computeFnSignature =
            m:
            let
              fn = m.fn or null;
              fnArgs =
                if fn != null && builtins.isFunction fn then builtins.functionArgs fn else { };
              hasSetPattern = fnArgs != { };
              argNames = builtins.attrNames fnArgs;
              argEntries = map (
                name:
                if fnArgs.${name} then "${name} ? ..." else name
              ) argNames;
            in
            if hasSetPattern then
              "{ ${lib.concatStringsSep ", " argEntries} }"
            else
              null;

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
            showTitle = opts.showTitle or true;
            showIndex = opts.showIndex or true;
            headingLevel = opts.headingLevel or 3;
          };
        };

      metadataJson = builtins.toJSON (metaToJson allLibsMeta);

      pythonWithTreeSitter = pkgs.python3.withPackages (ps: [ ps.tree-sitter ]);
      treeSitterNix = pkgs.tree-sitter-grammars.tree-sitter-nix;
      generateScript = ./_generate-docs.py;

      headerFile = pkgs.writeText "nix-lib-header.md" cfg.header;

      # Derivation with tree-sitter fn body extraction
      docsWithBodies = pkgs.runCommand "nix-lib-docs" {
        nativeBuildInputs = [ pythonWithTreeSitter ];
        passAsFile = [ "metadata" ];
        metadata = metadataJson;
      } ''
        mkdir -p $out
        python3 ${generateScript} \
          ${treeSitterNix}/parser \
          "$metadataPath" \
          ${cfg.src} \
          $TMPDIR/generated.md
        cat ${headerFile} $TMPDIR/generated.md > $out/docs.md
      '';

      # Fallback: pure Nix markdown generation (no fn body extraction)
      docsWithoutBodies = pkgs.writeTextFile {
        name = "nix-lib-docs";
        text = cfg.header + markdown.generateMarkdown allLibsMeta;
        destination = "/docs.md";
      };
    in
    {
      options.nix-lib.docs = {
        package = lib.mkOption {
          type = lib.types.package;
          default = if cfg.src != null then docsWithBodies else docsWithoutBodies;
          description = ''
            Markdown documentation package for all defined libs.

            The output contains a `docs.md` file with all lib definitions.
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

        showIndex = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to include the function index in generated docs.";
        };

        showTitle = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to include the top-level title and lib count in generated docs.";
        };

        headingLevel = lib.mkOption {
          type = lib.types.int;
          default = 3;
          description = ''
            Starting heading level for namespace and function headings.
            Default 3 (###). Set to 2 when the generated content is injected
            into a page with an H1 title, so namespaces become H2 siblings.
          '';
        };

        header = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = ''
            Markdown content prepended before generated function documentation.

            Use this for introductory text, override instructions, or any
            content that should appear before the function reference.
            Heading levels in the header should be consistent with `headingLevel`
            (e.g., use ## headings when headingLevel is 2).

            Example:
            ```nix
            nix-lib.docs.header = '''
              Overview of available library functions.

              ## Overriding functions

              You can override any function via...
            ''';
            ```
          '';
        };
      };
    };
}
