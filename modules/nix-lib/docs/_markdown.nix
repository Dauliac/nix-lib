# Markdown generation utilities (internal)
#
# Functions for generating markdown documentation from lib metadata.
#
{ lib }:
let
  # Generate markdown anchor from lib name
  nameToAnchor = name: builtins.replaceStrings [ "." ] [ "-" ] name;

  # Render a Nix type to a human-readable string
  typeToString =
    type:
    if type == null then
      null
    else if builtins.isString type then
      type
    else if builtins.isAttrs type && type ? description then
      type.description
    else
      builtins.toString type;

  # Pretty-print a Nix value for documentation (with depth limit)
  valueToNix =
    let
      go =
        depth: v:
        if depth <= 0 then
          "..."
        else if builtins.isString v then
          ''"${v}"''
        else if builtins.isInt v then
          toString v
        else if builtins.isBool v then
          if v then "true" else "false"
        else if builtins.isNull v then
          "null"
        else if builtins.isFunction v then
          "<function>"
        else if builtins.isList v then
          "[ ${lib.concatMapStringsSep " " (go (depth - 1)) v} ]"
        else if builtins.isAttrs v then
          "{ ${lib.concatStringsSep " " (lib.mapAttrsToList (k: val: "${k} = ${go (depth - 1) val};") v)} }"
        else
          toString v;
    in
    go 5;

  # Extract function arguments for documentation
  # Returns a string like "{ a, b, c ? default }" or null if not detectable
  fnArgsToString =
    meta:
    let
      fn = meta.fn or null;
      fnArgs = if fn != null && builtins.isFunction fn then builtins.functionArgs fn else { };
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
      # For curried functions, try to infer arg names from test args
      let
        tests = meta.tests or { };
        testNames = builtins.attrNames tests;
        firstTest = if testNames != [ ] then tests.${builtins.head testNames} else null;
        testArgNames =
          if firstTest != null && firstTest ? args && builtins.isAttrs firstTest.args then
            builtins.attrNames firstTest.args
          else
            [ ];
      in
      if testArgNames != [ ] then
        lib.concatStringsSep " → " testArgNames
      else
        null;

  # Generate index entry for a single lib
  libToIndexEntry =
    name: meta:
    let
      anchor = nameToAnchor name;
      fileLink = if meta.file or null != null then " ([source](${meta.file}))" else "";
    in
    "- [`${name}`](#${anchor})${fileLink}";

  # Render test cases as a markdown table
  testsToMarkdown =
    tests:
    let
      testNames = builtins.attrNames tests;
    in
    if testNames == [ ] then
      ""
    else
      let
        rows = map (
          testName:
          let
            t = tests.${testName};
            argsStr = valueToNix (t.args or { });
            expectedStr =
              if t.expected or null != null then valueToNix t.expected else "*(assertions)*";
          in
          "| ${testName} | `${argsStr}` | `${expectedStr}` |"
        ) testNames;
      in
      ''

        <details><summary><strong>Tests (${toString (builtins.length testNames)})</strong></summary>

        | Name | Input | Expected |
        |---|---|---|
        ${lib.concatStringsSep "\n" rows}

        </details>
      '';

  # Generate markdown for a single lib (heading level is provided externally)
  libToMarkdown =
    headingLevel: name: meta:
    let
      anchor = nameToAnchor name;
      heading = lib.concatStrings (lib.replicate headingLevel "#");
      visibleStr = if meta.visible or true then "" else " *(private)*";
      descStr = meta.description or "No description";
      argsStr =
        let
          rendered =
            if meta.fnSignature or null != null then
              meta.fnSignature
            else
              fnArgsToString meta;
        in
        if rendered != null then
          ''

            **Arguments:**
            ```nix
            ${rendered}
            ```
          ''
        else
          "";
      typeStr =
        let
          rendered = typeToString (meta.type or null);
        in
        if rendered != null then
          ''

            **Type:** `${rendered}`
          ''
        else
          "";
      fileStr =
        if meta.file or null != null then
          ''

            **Source:** [${meta.file}](${meta.file})
          ''
        else
          "";
      exampleStr =
        if meta.example or null != null then
          ''

            **Example:**
            ```nix
            ${meta.example}
            ```
          ''
        else
          "";
      testStr = testsToMarkdown (meta.tests or { });
    in
    ''
      ${heading} `${name}` {#${anchor}}${visibleStr}
      ${argsStr}${typeStr}
      ${descStr}
      ${fileStr}${exampleStr}${testStr}
    '';

  # Build a namespace tree from sorted lib names
  # Returns a nested attrset where leaves have __libs = [ { name, meta } ]
  # and branches have sub-namespaces as attrs
  buildNamespaceTree =
    cleanMeta: allSortedLibNames:
    builtins.foldl' (
      tree: name:
      let
        parts = lib.splitString "." name;
        # All parts except the last are namespace segments
        nsParts = lib.init parts;
        # Build path in tree for this namespace
        insertLib =
          currentTree: remainingParts:
          if remainingParts == [ ] then
            # We're at the target namespace - add the lib
            currentTree
            // {
              __libs = (currentTree.__libs or [ ]) ++ [
                {
                  inherit name;
                  meta = cleanMeta.${name};
                }
              ];
            }
          else
            let
              segment = builtins.head remainingParts;
              rest = builtins.tail remainingParts;
              existing = currentTree.${segment} or { };
            in
            currentTree // { ${segment} = insertLib existing rest; };
      in
      insertLib tree nsParts
    ) { } allSortedLibNames;

  # Render a namespace tree to markdown with hierarchical headings
  # libLevel: the heading level for libs at this depth (3 = ###, 4 = ####, etc.)
  renderNamespaceTree =
    tree: libLevel:
    let
      # Render libs at this level
      libsHere = tree.__libs or [ ];
      libDocs = lib.concatMapStrings (
        entry: libToMarkdown libLevel entry.name entry.meta
      ) libsHere;

      # Render sub-namespaces
      subKeys = builtins.sort (a: b: a < b) (
        builtins.filter (k: k != "__libs") (builtins.attrNames tree)
      );
      # Sub-namespace heading is at the same level as libs
      nsHeading = lib.concatStrings (lib.replicate libLevel "#");
      subDocs = lib.concatMapStrings (
        key:
        let
          subTree = tree.${key};
        in
        ''
          ${nsHeading} ${key}

          ${renderNamespaceTree subTree (libLevel + 1)}
        ''
      ) subKeys;
    in
    "${libDocs}${subDocs}";

  # Generate full markdown document
  generateMarkdown =
    allLibsMeta:
    let
      opts = allLibsMeta.__docsOptions or { };
      showIndex = opts.showIndex or true;
      showTitle = opts.showTitle or true;
      headingLevel = opts.headingLevel or 3;
      cleanMeta = builtins.removeAttrs allLibsMeta [ "__docsOptions" ];
      allSortedLibNames = builtins.sort (a: b: a < b) (builtins.attrNames cleanMeta);
      indexEntries =
        let
          renderIndexTree =
            tree: depth:
            let
              indent = lib.concatStrings (lib.replicate depth "  ");
              libsHere = tree.__libs or [ ];
              libEntries = lib.concatMapStringsSep "\n" (
                entry:
                let
                  anchor = nameToAnchor entry.name;
                  fileLink =
                    if entry.meta.file or null != null then " ([source](${entry.meta.file}))" else "";
                in
                "${indent}- [`${entry.name}`](#${anchor})${fileLink}"
              ) libsHere;
              subKeys = builtins.sort (a: b: a < b) (
                builtins.filter (k: k != "__libs") (builtins.attrNames tree)
              );
              subEntries = lib.concatMapStringsSep "\n" (
                key: "${indent}- **${key}**\n${renderIndexTree tree.${key} (depth + 1)}"
              ) subKeys;
            in
            lib.concatStringsSep "\n" (lib.filter (s: s != "") [ libEntries subEntries ]);
          nsTree = buildNamespaceTree cleanMeta allSortedLibNames;
        in
        renderIndexTree nsTree 0;
      libCount = builtins.length allSortedLibNames;

      # Build namespace tree and render with hierarchical headings
      # Root libs start at heading level 3 (###), namespace headings at same level
      nsTree = buildNamespaceTree cleanMeta allSortedLibNames;
      libDocs = renderNamespaceTree nsTree headingLevel;

      titleBlock =
        if showTitle then
          ''
            # nix-lib API Reference

            Generated documentation for all defined library functions.

            **Total libs:** ${toString libCount}

          ''
        else
          "";

      indexBlock =
        if showIndex then
          ''
            ## Index

            ${indexEntries}

          ''
        else
          "";
    in
    ''
      ${titleBlock}${indexBlock}
      ${libDocs}
    '';
in
{
  inherit
    nameToAnchor
    libToIndexEntry
    libToMarkdown
    generateMarkdown
    typeToString
    valueToNix
    testsToMarkdown
    fnArgsToString
    buildNamespaceTree
    renderNamespaceTree
    ;
}
