# `den-diagram`  -  primary-source research

Scope: research the `denful/den-diagram` Nix library from primary sources only
(GitHub API on the upstream repo and the docs page at
`https://denful.dev/ecosystem/den-diagram/`). Goal: decide whether nix-lib
(flake-parts + internal importTree, no `den`, no `flake-aspects`) can use it
to visualize its module graph for documentation, debugging, or onboarding.

All citations point at the upstream repo `denful/den-diagram` `main` branch,
verified via `gh api repos/denful/den-diagram/*` on 2026-09-26. Repo metadata:
MIT-licensed, 5 stars, 195 KB, 40 files, Nix-only, primary language `Nix`,
created 2026-05-21, last push 2026-09-24.

---

## 1. What it is, one sentence

> "Diagram library for [den](https://github.com/denful/den)  -  graph IR
> construction, filtering, and multi-format rendering of aspect-resolution
> pipelines."
> (`README.md:11`,
> `https://github.com/denful/den-diagram/blob/main/README.md`)

The unit of visualization is den's *aspect resolution*: how a `den` fx-pipeline
run selected which aspects, providers, and handlers apply to a given host,
class, and scope, and what got excluded or replaced along the way. It is not
a general-purpose flake-parts / Nixpkgs module visualizer.

## 2. Repo layout

`gh api repos/denful/den-diagram/git/trees/HEAD?recursive=1` (default branch
`main`) returns:

| Path | Size | Purpose |
| --- | --- | --- |
| `flake.nix` | 310 B | Declares `lib = import ./nix { inherit lib; }`. Sole input: `nixpkgs`. |
| `nix/default.nix` | 6.3 KB | Public entry point. Wires 20+ submodules together. |
| `nix/context.nix` | 4.2 KB | `context`, `projectScope`  -  build graph IR from capture data. |
| `nix/graph.nix` | 24.4 KB | Core IR construction: nodes, edges, entity kinds. |
| `nix/namespace.nix` | 3.1 KB | Static aspect graph builder (no host resolution). |
| `nix/filters/*.nix` | 6 files | `closure`, `diff`, `fold`, `predicate`, `presence`, `reshape`. |
| `nix/mermaid.nix` | 13.2 KB | Mermaid flowchart renderer. |
| `nix/dot.nix` | 4.4 KB | Graphviz DOT renderer. |
| `nix/plantuml.nix` | 4.1 KB | PlantUML renderer. |
| `nix/c4.nix` | 9.9 KB | C4 diagrams (PlantUML + Mermaid variants). |
| `nix/sequence.nix` | 18.3 KB | Sequence and policy-sequence diagrams. |
| `nix/sankey.nix`, `treemap.nix`, `mindmap.nix`, `state.nix` | | Specialised Mermaid renderers. |
| `nix/fleet-ir.nix` | 12.8 KB | Fleet-scale IR: multiple hosts / environments. |
| `nix/fleet-views.nix` | 28.1 KB | Fleet views: DAG, aspect matrix, pipe flow, policy map. |
| `nix/fleet.nix` | 2 KB | `fleet.of { hosts, flakeName }`. |
| `nix/export.nix` | 8.7 KB | Turn view defs into `.md` / `.svg` derivations. |
| `nix/render-infra.nix` | 3.4 KB | `pkgs`-touching export machinery (mermaid-cli, graphviz, plantuml). |
| `nix/render-context.nix` | 1.2 KB | `renderContext`  -  ties renderers to `pkgs` for SVG builds. |
| `nix/themes.nix` | 8.9 KB | Base16 palette to theme. |
| `nix/colors.nix` | 2.3 KB | Node color helpers. |
| `nix/json.nix` | 1.4 KB | `toJSON` graph IR serializer. |
| `nix/util.nix` | 13.1 KB | Pure helpers. `chainOf`, `dedupBy`, sanitizers. |
| `tests/tests.nix` | 27.5 KB | Standalone tests. Feed synthetic trace entries; verify renderer output. |
| `checkmate/modules/*.nix` | | Formatter + tests wiring for `denful/checkmate`. |
| `LICENSE` | 1069 B | MIT (`gh api repos/denful/den-diagram` -> `license.spdx_id: "MIT"`). |

The full `flake.nix` (`gh api repos/denful/den-diagram/contents/flake.nix`):

```nix
{
  description = "Diagram library for den  -  graph IR, renderers, and fleet views";
  inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
    in
    {
      lib = import ./nix { inherit lib; };
    };
}
```

Sole flake input: `nixpkgs` (nixpkgs-unstable channel). Verified against
`flake.lock`: one node, no transitive inputs. So den-diagram is a leaf flake
just like `import-tree` (§9 of `import-tree.md`), but with a mandatory
`nixpkgs` for `lib`.

## 3. What it visualizes

### 3.1 The primary route: capture -> graph -> render

`README.md:27-56` describes a five-stage pipeline:

```
capture  ->  graph  ->  filter  ->  render  ->  export
(in den)     ------------  (in den-diagram)  ---------
```

Verbatim from `README.md:35`:

| Stage | Module(s) | Input | Output | Responsibility |
|-------|-----------|-------|--------|---------------|
| **Capture** | `den.lib.capture` (in den) | Resolved aspect tree | Structured trace entries | Run fx pipeline with tracing handlers, collect events |
| **Graph** | `context.nix`, `graph.nix` | Trace entries | Format-agnostic graph IR (nodes, edges, entity kinds) | Build graph IR from flat trace entries |
| **Filter** | `filters/` | Graph IR | Pruned/reshaped graph IR | Prune, fold, slice, diff |
| **Render** | `mermaid.nix`, `dot.nix`, `plantuml.nix`, ... | Graph IR | Diagram source strings | Emit format-specific text |
| **Export** | `export.nix`, `render-infra.nix` | Source strings + `pkgs` | Nix derivations (`.md`, `.svg`) | Build derivations via mermaid-cli/graphviz/plantuml |

The load-bearing sentence, `README.md:47-48`:

> "The first stage (capture) lives in den because it drives the fx pipeline.
> Everything after that is den-diagram  -  pure functions over plain attrsets,
> with `export` being the only stage that touches `pkgs`."

Canonical usage (`README.md:53-72`):

```nix
diagram = inputs.den-diagram.lib;

# 1. Capture  -  runs in den, produces trace data
captured = den.lib.capture.captureWithPathsWith {
  classes = [ "nixos" "homeManager" ];
  root = den.lib.resolveEntity "host" { inherit host; };
  ctx = { inherit host; };
};

# 2. Graph  -  builds format-agnostic IR from trace entries
g = diagram.context {
  entries = captured.entries;
  ctxTrace = captured.ctxTrace;
  name = host.name;
};

# 3. Render  -  emit diagram source in any supported format
rendered = diagram.toMermaid g;
```

The trace entries feeding `diagram.context` are `{ name, parent, class,
provider, excluded, excludedFrom, replacedBy, isProvider, handlers,
hasAdapter, hasClass, isParametric, fnArgNames, entityKind, entityInstance,
isPolicyDispatch, policyName, from, to }` records (verbatim schema from
`tests/tests.nix:9-46` `mkEntry`). Every field is aspect-resolution vocabulary:
`provider` chain, `excluded/replacedBy` (aspect overrides), `handlers`
(fx effect handlers), `isPolicyDispatch/policyName` (den's policy layer),
`entityKind/entityInstance` (host, environment, user, etc.). None of these
map to flake-parts module concepts (imports, options, config, perSystem).

### 3.2 The secondary route: namespaceGraph over static aspects

`nix/namespace.nix` builds a graph "walking aspect declarations (no host
resolution)". Its input contract (`nix/namespace.nix:8-11`):

```nix
namespaceGraph = { name ? "aspects", aspects, direction ? "TD",
                   filter ? (_: true) }: ...
```

and the aspect-shape probe (`nix/namespace.nix:13-15`):

```nix
isAspect =
  v: builtins.isAttrs v && v ? includes && v ? name && v ? meta
     && builtins.isAttrs (v.meta or null);
```

So `namespaceGraph` still expects attribute values that carry `includes`,
`name`, `meta.handleWith`, `provides`, `meta.<chain>` (see `util.chainOf`,
below). These are den / `flake-aspects` idioms. A plain flake-parts module
(`{ imports, options, config, ... }: ...`) does not match  -  the `isAspect`
probe rejects it, `filterAttrs` empties, and the resulting graph has zero
nodes.

Public exposure (`nix/default.nix:100-104`):

```nix
graph = {
  build = graphLib.buildGraph;
  ofNamespace = namespaceGraph;
} // filtersLib;
```

Called as `diagram.graph.ofNamespace { aspects = den.aspects; }`
(`README.md:80-83`).

### 3.3 Fleet route

`README.md:74-78`:

```nix
fleetData = diagram.fleet.of { hosts = den.hosts; flakeName = "my-fleet"; };
diagram.toC4Context fleetData;
```

`nix/fleet.nix` iterates `den.hosts` (a `den`-shaped attrset), captures each,
and unions the resulting IRs. Again den-specific.

### 3.4 What ends up in the IR

`nix/graph.nix:24-51` defines `emptyNode`  -  the schema every node inherits:

```nix
emptyNode = {
  id = ""; label = ""; fullLabel = ""; pathKey = "";
  shape = "rect"; style = "default";
  entityKind = null; entityInstance = null;
  classes = [ ]; class = ""; perClass = { };
  fnArgNames = [ ]; isParametric = false;
  isProvider = false; providerPath = [ ];
  hasClass = false;
  isExcluded = false; isReplaced = false;
  isPolicyDispatch = false; policyName = null;
  from = null; to = null;
};
```

Note the fields: `providerPath`, `isPolicyDispatch`, `classes`, `perClass`,
`entityKind`, `isReplaced`. These are den's aspect-resolution vocabulary,
not Nixpkgs module system vocabulary. There is no `imports`, no `options`,
no `config`, no `perSystem`, no attribute-path anywhere in the schema.

## 4. Output formats

Full renderer inventory (`nix/default.nix:132-235`, cross-referenced with
`README.md:107-124`):

| Function | Format | Backing renderer |
| --- | --- | --- |
| `toMermaid` | Mermaid flowchart | `mermaid.nix` |
| `toDot` | Graphviz DOT | `dot.nix` |
| `toPlantUML` | PlantUML | `plantuml.nix` |
| `toC4Component`, `toC4Container`, `toC4Context` | PlantUML C4 | `c4.nix` |
| `toC4ComponentMermaid`, `toC4ContainerMermaid`, `toC4ContextMermaid` | Mermaid C4 | `c4.nix` |
| `toSequenceMermaid`, `toSequenceMermaidExpanded` | Mermaid sequence | `sequence.nix` |
| `toPolicySequenceMermaid` | Policy-dispatch sequence | `sequence.nix` |
| `toScopeEdgesMermaid` | Scope edges | `sequence.nix` |
| `toSankeyMermaid`, `toFleetSankeyMermaid`, `toFanMetricsSankey` | Sankey | `sankey.nix` |
| `toTreemapMermaid`, `toFleetTreemapMermaid`, `toFleetProviderMatrix` | Treemap / matrix | `treemap.nix` |
| `toMindmapMermaid` | Mindmap | `mindmap.nix` |
| `toStateMermaid` | State diagram | `state.nix` |
| `toPipeFlowMermaid` | Pipe data flow | `fleet-views.nix` |
| `toScopeTopologyMermaid` | Scope topology | `fleet-views.nix` |
| `toAspectMatrixMermaid` | Aspect matrix | `fleet-views.nix` |
| `toPolicyResolutionMapMermaid` | Policy resolution map | `fleet-views.nix` |
| `toPipeSequenceMermaid` | Pipe sequence | `fleet-views.nix` |
| `toFleetDagMermaid` | Fleet DAG | `fleet-views.nix` |
| `toJSON` | Graph IR JSON | `json.nix` |

Each has a `*With` variant accepting `{ theme, mermaidConfig }`
(`nix/default.nix:239-256`).

Final deliverables (`README.md:88-92`, `nix/export.nix:11-29`): `.md` files
that embed the diagram source in a fenced code block plus, optionally, an
`.svg` image next to it. The `.svg` comes from `render-infra.nix` invoking
`mermaid-cli`, `graphviz`, or `plantuml` in a build derivation.

## 5. Inputs required

Dependency tree, verbatim from `README.md:129-137`:

```
den                           den-diagram
+-------------------+         +----------------------------------+
| captureWithPaths  |- data ->| graph     -> format-agnostic IR  |
| captureFleet      |         | filters   -> pruned IR           |
| captureAll        |         | renderers -> source strings      |
|                   |         | export    -> derivations         |
+-------------------+         +----------------------------------+
```

And `README.md:127`:

> "Den-diagram depends only on `nixpkgs.lib`. It has no dependency on den's
> fx pipeline or module system. The dependency is one-directional:
> den -> den-diagram."

That is technically true at the **flake-input** level: `den-diagram`'s
`flake.nix` does not `follows` or `inputs` `den`. But the **data-shape**
dependency is total: without den, or something that emits den-shaped trace
entries / aspect records, the library has no useful input.

Concrete input requirements per entry point:

- `diagram.context { entries, ctxTrace, name, ... }`: requires trace
  entries as produced by `den.lib.capture.captureWithPathsWith`. Schema in
  §3.1. **Not producible from a flake-parts config without writing your own
  capture stage that fabricates the schema.**
- `diagram.graph.ofNamespace { aspects, ... }`: requires an attrset of
  aspects, each `{ name, includes, meta, provides, ... }` where `meta` is
  an attrset (`nix/namespace.nix:14`). **Not what flake-parts modules look
  like.**
- `diagram.fleet.of { hosts, flakeName }`: requires `den.hosts`. Explicit
  den dependency.
- `diagram.projectScope { fleetCapture, kind, name }`: requires a fleet
  capture, i.e. a fleet-shape output of `captureFleet`. Explicit den
  dependency.
- `diagram.renderContext { pkgs, theme }.mmdSourceToSvg`: `pkgs` (with
  `mermaid-cli` or `graphviz` or `plantuml` available for the requested
  format). No den dependency at this stage  -  a raw Mermaid source string
  can be piped in. This is the only stage of the library reachable without
  a den-shaped input.

Standalone Mermaid rendering from a bespoke graph IR is technically possible
(the tests do this  -  `tests/tests.nix` feeds synthetic entries via `mkEntry`
and asserts on renderer output). But you would have to build the entries
yourself in the aspect-resolution vocabulary, node by node. There is no
`from-flake-parts` helper.

## 6. License, size, dependencies

- License: **MIT** (`LICENSE`, 1069 B; `gh api repos/denful/den-diagram` ->
  `license.spdx_id: "MIT"`).
- Repo size: **195 KB** (per repo metadata) / **~250 KB** counted across
  40 tracked files.
- Nix-only library. No compiled artifacts, no vendored binaries.
- Flake input surface: `nixpkgs` only.
- SVG export runtime dependencies (needed at derivation-build time when you
  ask for `.svg`): `mermaid-cli` (nodejs), `graphviz`, `plantuml`. Not
  needed for pure `toMermaid` / `toDot` / `toPlantUML` source-string
  generation.
- Depends *conceptually* on den's capture stage for anything beyond
  namespace-graph / synthetic-entry usage.
- No `nixpkgs` version pin beyond channel  -  `nixpkgs-unstable`. Consumers
  who `follows` nixpkgs get their own version.

## 7. Verdict for nix-lib

**Not adoptable as-is for visualizing nix-lib's flake-parts + importTree
module graph.**

Reasoning:

1. **Vocabulary mismatch.** den-diagram's IR is aspect-resolution-shaped
   (`provider` chain, `excluded/replacedBy`, `handlers`, `entityKind`,
   `isPolicyDispatch`). nix-lib is flake-parts-shaped (`imports`, `options`,
   `config`, `perSystem`, `flakeModules`, `nixosModules`, `collectors`,
   `adapterDefs`). None of the primary entry points (`context`, `fleet.of`,
   `projectScope`) accept anything flake-parts-flavoured. `graph.ofNamespace`
   explicitly probes for `v ? includes && v ? meta` and drops everything
   else (`nix/namespace.nix:14`).

2. **Missing capture layer.** The five-stage pipeline is `capture -> graph
   -> filter -> render -> export`. Stage 1 is where an fx-effect-instrumented
   run of den collects the events that form the graph. For a plain
   flake-parts config, nothing analogous exists  -  flake-parts evaluates via
   `evalModules` and does not emit trace events describing module inclusion,
   option merges, or per-system fan-out. To feed den-diagram from nix-lib
   you would have to write a bespoke capturer that walks a flake-parts
   evaluation and synthesizes den-shaped trace entries. That is not a small
   project (the entry schema has 18 fields, several with load-bearing
   semantics like `provider` chains and `policyName`).

3. **The renderers are usable in isolation, but not helpful in isolation.**
   `diagram.toMermaid` / `toDot` / `toPlantUML` are just IR -> string
   functions. You could hand-roll an IR that has just `nodes` and `edges`
   plus the required `entityKinds` / `entityEdges` (see `nix/namespace.nix`
   final `in { ... }` block for the minimum shape) and let the renderers
   emit Mermaid. But at that point you are re-writing your own IR
   construction on top of a library whose IR was not designed for
   flake-parts. Simpler to emit Mermaid directly.

4. **What would be needed** to actually adopt this: either (a) adopt den
   itself, migrate nix-lib's modules to aspects, and get diagrams for free;
   or (b) write a `flakeParts -> den-diagram.IR` adapter that fabricates
   trace-entry-shaped records from `config.flake.modules.*`,
   `config.perSystem`, `config.flakeModules`, etc. Neither is
   proportionate to "show the module graph in docs".

## 8. Integration sketch (only if we later decide to go this way)

For the sake of completeness, if we ever wanted to render an IR from
nix-lib's structure without adopting den:

- Location: a new file `dev/diagrams.nix` (in the dev partition per
  `flake-parts-partitions.md`), so `den-diagram` never enters the consumer
  lock.
- Adapter: `nix/lib/to-den-diagram-ir.nix` (nix-lib-internal), producing a
  minimal IR of shape `{ rootName, rootId, direction, nodes, edges,
  entityKinds = [ ], entityEdges = [ ] }` from the module tree we already
  discover via importTree.
- Entry points would be `diagram.toMermaid` and `diagram.toDot` only. C4,
  policy sequence, sankey, treemap, mindmap, state, and every `fleet*`
  view require IR fields we would not populate.
- Invocation: a `mise run diagrams:build` task that calls a derivation
  building `.md` + `.svg` per top-level module directory, committing
  regenerated output under `docs/diagrams/`.
- Consumer impact: none. Everything lives in the dev partition.

But the cost/benefit is bad. For roughly the same code size as the adapter,
we could emit Mermaid text directly from our own module-discovery walk and
skip den-diagram entirely. den-diagram's value is the aspect-domain analyses
(policy resolution map, aspect matrix, fleet DAG, class-slice, diff-classes)
 -  none of which apply to flake-parts.

## 9. Sources

- Repo root: <https://github.com/denful/den-diagram>
- README: <https://github.com/denful/den-diagram/blob/main/README.md>
- `flake.nix`: <https://github.com/denful/den-diagram/blob/main/flake.nix>
- `nix/default.nix`: <https://github.com/denful/den-diagram/blob/main/nix/default.nix>
- `nix/context.nix`: <https://github.com/denful/den-diagram/blob/main/nix/context.nix>
- `nix/graph.nix`: <https://github.com/denful/den-diagram/blob/main/nix/graph.nix>
- `nix/namespace.nix`: <https://github.com/denful/den-diagram/blob/main/nix/namespace.nix>
- `nix/export.nix`: <https://github.com/denful/den-diagram/blob/main/nix/export.nix>
- `nix/util.nix`: <https://github.com/denful/den-diagram/blob/main/nix/util.nix>
- `tests/tests.nix`: <https://github.com/denful/den-diagram/blob/main/tests/tests.nix>
- Repo metadata (license, size, default branch): `gh api repos/denful/den-diagram` on 2026-09-26.
- Tree listing: `gh api 'repos/denful/den-diagram/git/trees/HEAD?recursive=1'` on 2026-09-26.
- Docs page (thin wrapper around README): <https://denful.dev/ecosystem/den-diagram/>
- Related den ecosystem repos observed via `gh search repos --owner=denful`:
  `denful/den` (aspect-oriented context-driven Nix), `denful/flake-aspects`
  (flake.modules transposition for aspect-oriented Dendritic Nix),
  `denful/dendrix` (Dendritic Nix community distribution),
  `denful/import-tree`, `denful/checkmate`, `denful/flake-file`,
  `denful/garden`, `denful/dendritic-unflake`, `denful/nfx`, `denful/dnx`.

End of research.
