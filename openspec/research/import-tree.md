# `import-tree`  -  primary-source research

Scope: research the `denful/import-tree` Nix library from primary sources
only (README, source, docs site content in the repo, and one working
consumer at `~/ghq/github.com/Dauliac/nix-oci`). Goal: enough depth for
nix-lib to decide whether to adopt it internally without exposing it as
a client-facing dependency.

All citations point at either the upstream repo (`denful/import-tree`
`main` branch, tree SHA `eb1b52eaecc57f7c136d07ae8a93e724dfecac46` at
time of research  -  see `gh api repos/denful/import-tree/git/trees/HEAD`),
or the local `nix-oci` consumer.

Note on the fork history: the `mightyiam/dendritic` README (lines 108-110)
originally credited `vic/import-tree`; the repo is now published at
`denful/import-tree` and `nix-oci`'s `flake.lock` shows both entries
side-by-side (`import-tree` under `denful`, `import-tree_2` under `vic`)
so `vic == denful` (renamed / re-owned; identical library).

---

## 1. What it does, one sentence

> "Recursively import Nix modules from a directory, with a simple,
> extensible API."  -  `README.md:14`
> (`https://github.com/denful/import-tree/blob/main/README.md#L14`)

`import-tree ./modules` returns a Nix module whose `imports` list is
every `.nix` file discovered under `./modules`, skipping paths that
contain `/_`. It also carries a builder API (`.filter`, `.map`,
`.match`, `.addAPI`, `.addPath`, `.addScoped`, `.pipeTo`, `.leaves`,
`.files`, `.new`, `.initFilter`, `.withLib`, `.pipeTo`, combinator
call form) to shape which files are picked up and what they get
transformed into before being returned.

## 2. Repo layout

`gh api repos/denful/import-tree/git/trees/HEAD?recursive=1` returned
these primary artefacts:

| Path | Size | Purpose |
| --- | --- | --- |
| `default.nix` | 8.2 KB, 268 lines | The entire library. Single file. |
| `flake.nix` | 31 bytes | `{ outputs = _: import ./.; }`  -  no inputs. |
| `tests.nix` | 10.6 KB, 382 lines | `nix-unit` test spec (exercises every API). |
| `shell.nix` | 189 B | Dev shell. |
| `README.md` | 3.3 KB | User-facing intro, 3 install patterns. |
| `docs/src/content/docs/**/*.mdx` | | Astro Starlight site source. |
| `tree/**` | | Test fixtures (`tree/a`, `tree/modules`, `tree/_scoped`, `tree/x`, `tree/hello`). |

The `flake.nix` content in full (`gh api repos/denful/import-tree/contents/flake.nix`):

```nix
{
  outputs = _: import ./.;
}
```

That is literally all of it  -  no `inputs`, no `follows`. Consequently
`flake.lock` entries for import-tree in any consumer show only a
`locked` and an `original` block, no `inputs` key. Verified in
`~/ghq/github.com/Dauliac/nix-oci/flake.lock`  -  the `"import-tree"`
node has no `"inputs"` field, so it is a **leaf** input.

## 3. API surface  -  full signatures and semantics

Verbatim from `docs/src/content/docs/reference/api.mdx` (231 lines,
tree SHA `b62a003806d1a7ce01e2907a7946a25c37f4d766`).

### 3.1 Construction / obtaining the object

- As a flake input (`api.mdx:11-14`):

  ```nix
  inputs.import-tree.url = "github:denful/import-tree";
  # Then use: inputs.import-tree
  ```

- As a plain import (`api.mdx:17-19`):

  ```nix
  let import-tree = import ./path-to/import-tree;
  ```

- Or from a fetched tarball (non-flake) (`quick-start.mdx:27-33`):

  ```nix
  let
    import-tree = import (builtins.fetchTarball {
      url = "https://github.com/denful/import-tree/archive/main.tar.gz";
    });
  ```

The resulting value is a callable attrset  -  every method below is an
attribute; calling the value as a function is the `functor` code path
in `default.nix:180-186`.

### 3.2 `import-tree <path | [paths]>`  -  the core call

Signature (`api.mdx:27`, `default.nix:180-186`):

```
import-tree : (Path | [Path]) -> Module
```

- Accepts a path or a nested list of paths (`api.mdx:31-35`):

  ```nix
  import-tree ./modules
  import-tree [ ./modules ./extra ]
  import-tree [ ./a [ ./b ] ]   # nested lists are flattened
  ```

- Other import-tree objects can appear in the list as if they were
  paths (`api.mdx:37`, and `tests.nix` case
  `"test can take other import-trees as if they were paths"`,
  lines 195-207).

- Attrsets with an `outPath` attribute (like flake inputs) are treated
  as paths (`api.mdx:43-47`):

  ```nix
  import-tree [ { outPath = ./modules; } ]
  ```

- When the argument is an attrset with an `options` attribute,
  import-tree assumes it is being evaluated as a module. This lets a
  pre-configured `import-tree` object appear directly in `imports`
  (`api.mdx:39-41`).

  The dispatch that makes this work is `default.nix:180-186`:

  ```nix
  functor =
    self: arg:

    if builtins.isFunction arg && builtins.functionArgs arg == { } then
      arg self # arg is a combinator pass the self import-tree obj
    else if inModuleEval arg then
      perform self.__config [ ] arg
    else
      perform self.__config arg;
  ```

  Where `inModuleEval = and (x: x ? options) builtins.isAttrs`
  (`default.nix:178`).

- Non-path values (attrsets without `outPath`) are passed through the
  filter and included if they pass (`api.mdx:49`). See
  `tests.nix:220-236` (`"test passes non-paths without string conversion"`).

**What is returned**  -  this is the load-bearing detail:
`default.nix:20-27`:

```nix
module =
  _:
  let
    files = leaves path;
  in
  {
    imports = if scoped == { } then files else map scoped-import-module files;
  };
```

The returned value is a lambda `_: { imports = <list-of-paths>; }`.
Comment at `default.nix:16-19`:

> "module stays a function: callers may apply it as a module function,
> and keeping it a lambda defers the tree read (`leaves path`) until
> module-eval time rather than at `it ./dir` construction time. It no
> longer needs `lib`  -  the reader is pure `builtins`  -  so the argument
> is ignored."

Consequence: the recursive `builtins.readDir` walk (via
`listDirFilesRecursive`, `default.nix:127-136`) runs **when the outer
module system evaluates the module**, not at `import-tree ./dir` call
time. `mkFlake` (or any `evalModules`) triggers it once during
evaluation and the result is a plain flat `imports` list of Nix
`Path` values.

### 3.3 Filtering

Every filter is a *left-fold accumulator*  -  repeated calls compose
with AND (`default.nix:207-215`):

```nix
filter    = filterf: accAttr "filterf" (and filterf);
filterNot = filterf: accAttr "filterf" (andNot filterf);
match     = regex: accAttr "filterf" (and (matchesRegex regex));
matchNot  = regex: accAttr "filterf" (andNot (matchesRegex regex));
```

- **`.filter <fn>`**  -  `fn : string -> bool`, applied to `toString`
  of each candidate file path. Multiple `.filter` calls AND together.
  (`api.mdx:57-63`, `filtering.mdx:21-31`.)

  ```nix
  import-tree.filter (lib.hasInfix ".mod.") ./modules
  ```

- **`.filterNot <fn>`**  -  inverse. (`api.mdx:67-73`.)

- **`.match <regex>`**  -  `builtins.match` against the **full** path
  string. `builtins.match` requires full-string match, so callers
  usually wrap with `.*` (`filtering.mdx:62-64`, ` Aside caution`).
  (`api.mdx:75-83`.)

  ```nix
  import-tree.match ".*/[a-z]+_[a-z]+\.nix" ./modules
  ```

- **`.matchNot <regex>`**  -  inverse. (`api.mdx:85-89`.)

- **`.initFilter <fn>`**  -  *replaces* the default filter entirely.
  Default is `andNot (hasInfix "/_") (hasSuffix ".nix")`
  (`default.nix:92`). Use to hunt non-`.nix` files, or to change the
  ignore convention. Also applies to non-path items in explicit
  import lists (`api.mdx:91-101`, `filtering.mdx:80-91`).

  ```nix
  import-tree.initFilter (lib.hasSuffix ".md") ./docs
  import-tree.initFilter (p: lib.hasSuffix ".nix" p && !lib.hasInfix "/skip/" p)
  ```

  Non-accumulating: it replaces `initf` via `mergeAttrs`
  (`default.nix:220`).

### 3.4 Transformation

- **`.map <fn>`**  -  `fn : Path -> a`. Each discovered path is passed
  through `fn`. Multiple `.map` calls compose left-to-right; first
  call runs first (`default.nix:213`: `map = mapf: accAttr "mapf" (compose mapf);`).
  (`api.mdx:106-116`, `mapping.mdx`.)

  ```nix
  import-tree.map lib.traceVal ./modules        # trace each path
  import-tree.map (p: { imports = [ p ]; })      # wrap in module
  import-tree.map import                         # actually import
  ```

  Applied inside `leaves` at `default.nix:112`:
  `map mapf files`.

### 3.5 Path accumulation

- **`.addPath <path>`**  -  appends to the internal `paths` list.
  Accumulating. When the object is later called with `[]` (or with
  `.result`, or via `.files`), the accumulated paths are used
  (`default.nix:214`: `addPath = path: accAttr "paths" (p: p ++ [ path ]);`,
  and the flatten happens in `leaves` at `default.nix:114-117`).
  (`api.mdx:122-129`.)

  ```nix
  (import-tree.addPath ./vendor).addPath ./modules
  # discovers files in both directories
  ```

### 3.6 Extension: `.addAPI`

Signature (`api.mdx:137`, `default.nix:216`):

```
.addAPI : { <name> = self -> a; ... } -> import-tree'
```

- Each attribute is a function receiving the *current* import-tree
  (post-update) as `self` and returning anything (typically a new
  import-tree, but not necessarily) (`api.mdx:137-147`).

  ```nix
  import-tree.addAPI {
    maximal = self: self.addPath ./all-modules;
    feature = self: name: self.filter (lib.hasInfix name);
  }
  ```

- The added attributes appear directly on the extended object. Access
  goes through `boundAPI` at `default.nix:198`:

  ```nix
  boundAPI = builtins.mapAttrs (_: g: g current) updated.api;
  ```

  where `current = config update`  -  a freshly-bound import-tree.

- Multiple `.addAPI` calls preserve earlier additions
  (`api.mdx:150-155`, and `tests.nix:158-167`
  `"test preserves previous API extensions"`).

- **Late binding**: `self.foo` inside an added method resolves at
  call time, so you can reference methods added by a later
  `.addAPI` call (`api.mdx:159-167`, `tests.nix:170-177`
  `"test API extensions are late bound"`):

  ```nix
  let
    first = import-tree.addAPI { res = self: self.late; };
    extended = first.addAPI { late = _self: "hello"; };
  in
  extended.res  # => "hello"
  ```

### 3.7 Scoped imports: `.addScoped`

Signature (`api.mdx:150`, `default.nix:214`):

```
.addScoped : AttrSet -> import-tree'
```

- Merges attrs into the scope handed to imported modules via
  `builtins.scopedImport`. Accumulating
  (`default.nix:214`: `addScoped = attrs: accAttr "scoped" (s: s // attrs);`).
  (`api.mdx:150-185`.)

- Machinery: `default.nix:29-58`  -  the library's own `scoped-import`
  wraps `builtins.scopedImport`, defaulting `__nixPath = []` and
  `builtins.nixPath = []` for hermeticity, and re-exposes the scope
  as `builtins.scoped` inside imported files so nested invocations
  can inherit it.

  ```nix
  scoped-import =
    scoped:
    builtins.scopedImport (
      { __nixPath = [ ]; }
      // scoped
      // {
        builtins =
          scoped.builtins or (builtins // { nixPath = [ ]; })
          // { inherit scoped; };
      }
    );

  scoped-import-module = file: {
    _file = file;                    # keep original path for error messages
    imports = [ (scoped-import scoped file) ];
  };
  ```

  When `scoped != {}`, `module.imports` becomes
  `map scoped-import-module files` instead of `files`
  (`default.nix:26`), so each file goes through `scopedImport` with
  the accumulated scope, and each carries `_file = file` so error
  messages still point at the original path.

  Usage (`api.mdx:154-157`):

  ```nix
  import-tree.addScoped { foo = 42; mylib = lib; } ./modules
  # modules can now use `foo` and `mylib` directly
  ```

  Inside a scoped-imported module (`api.mdx:180-185`):

  ```nix
  { imports = [ (import-tree.addScoped (builtins.scoped // { bar = foo; }) ./other-modules) ]; }
  ```

### 3.8 Output / non-module usage

- **`.leaves`**  -  flips the pipeline into "return the list, not a
  module". Under the hood it sets `pipef = i: i;`
  (`default.nix:224`), so calling `configured.leaves ./dir` returns
  the flat file list (`api.mdx:191-198`, `outside-modules.mdx:18-24`).

  ```nix
  import-tree.leaves ./modules
  # => [ ./modules/a.nix ./modules/b.nix ]
  ```

- **`.files`**  -  shorthand for `.leaves.result` (`default.nix:229`:
  `files = current.leaves.result;`). Useful when paths were pre-added
  with `.addPath` (`api.mdx:200-207`, `outside-modules.mdx:27-35`).

- **`.pipeTo <fn>`**  -  returns a configured import-tree that, when
  called with a path, produces `fn (leaves path)`
  (`default.nix:222`: `pipeTo = pipef: mergeAttrs { inherit pipef; };`,
  and `default.nix:14`: `result = if pipef == null then module else pipef (leaves path);`).
  (`api.mdx:209-216`.)

  ```nix
  import-tree.pipeTo builtins.length ./modules
  # => 3
  ```

- **`.result`**  -  evaluate the current configuration with an empty
  root path (`default.nix:227`: `result = current [ ];`). Equivalent
  to calling the object with `[]`. (`api.mdx:218-225`.)

- **`.new`**  -  a fresh, cleared instance
  (`default.nix:231`: `new = callable;`). (`api.mdx:227-231`.)

- **`.withLib <lib>`**  -  retained as a no-op for backward
  compatibility (`default.nix:218-220`,
  `README.md`-adjacent test: `tests.nix:15-17`
  `"test withLib is a no-op kept for backward compatibility"`). The
  tree reader is now pure `builtins`, so `lib` is not required.

- **`.leafs`**  -  deprecated alias for `.leaves`
  (`default.nix:225-228`, emits `builtins.warn`).

- **`.pipeTo`**, **`.result`**, **`.new`**, **`.files`**, **`.leaves`**
  are all exposed on every import-tree object regardless of
  configuration state (`default.nix:191-232`).

### 3.9 Combinator call form

If the argument to the import-tree object is a **zero-arg function**
(i.e. `builtins.functionArgs arg == { }`), it is treated as a
combinator: called with `self` and its return value becomes the new
state. `default.nix:180-183`:

```nix
if builtins.isFunction arg && builtins.functionArgs arg == { } then
  arg self # arg is a combinator pass the self import-tree obj
```

This is the fluent multi-arg style (`combinator.mdx:12-22`):

```nix
# Without combinators (verbose)
let
  configured = import-tree.map import;
  leaves = configured.leaves;
in
leaves ./modules

# With combinators (terse)
import-tree (it: it.map import) (it: it.leaves) ./modules
```

Because each combinator returns a new import-tree, and the returned
value is itself callable, chains of combinators are just repeated
function application:

```nix
import-tree
  (it: it.addPath ./modules)                 # first: add a path
  (it: it.filter (lib.hasSuffix "mod.nix"))  # then: filter
  ./src                                      # finally: evaluate
```

Exercised in `tests.nix:277-281`
`"test combinator syntax to compose import-tree"`:

```nix
combinator."test combinator syntax to compose import-tree" = {
  expr = it (it: it.withLib lib) (it: it.leaves) ./tree/_scoped;
  expected = [ ./tree/_scoped/foo.nix ];
};
```

### 3.10 Internal state model

`default.nix:143-232`  -  the whole builder is one closure. Initial
state:

```nix
initial = {
  api = { };
  mapf = i: i;
  filterf = _: true;
  paths = [ ];
  scoped = { };

  __functor = config: update: let updated = update config; ... in ...;
};
```

`initial (config: config)` bootstraps the first import-tree. Every
method returns a new tree whose `__config` is the updated state,
`__functor` is `functor` (dispatch on the arg), and every previously
added API method is re-bound to the new `self`. That is why chains
compose predictably: state is a pure accumulator, and every returned
object is a full replacement.

## 4. `default.nix`  -  path resolution walkthrough

`default.nix:82-119`  -  this is the file-discovery loop, verbatim:

```nix
leaves =
  let
    nixFilter = andNot (hasInfix "/_") (hasSuffix ".nix");

    initialFilter = if initf != null then initf else nixFilter;

    pathFilter = compose (and filterf initialFilter) toString;

    otherFilter = and filterf (if initf != null then initf else (_: true));

    # Filter an explicit user supplied path:
    filterFiles =
      x:
      if hasOutPath x then
        filterFiles x.outPath
      else if isImportTree x then
        # Use the foreign import-tree filtering so that relative path are correctly handled:
        (x.filter filterf).files
      else if isPathLike x then
        if builtins.readFileType x == "directory" then
          let
            dir = toString x;
            relativize = file: removePrefix dir (toString file);
          in
          builtins.filter (compose pathFilter relativize) (listDirFilesRecursive x)
        else
          # For explicit user-supplied (non-directory) files, ignore filter:
          x
      else if otherFilter x then
        x
      else
        [ ];
  in
  root:
  let
    roots = flatten [ paths root ];
    files = flatten (map filterFiles roots);
  in
  map mapf files;
```

Key behaviors falling out of this:

1. `paths` (from `.addPath`) come **first**, then the argument
   passed at call time (`roots = flatten [ paths root ]`,
   `default.nix:115-116`).
2. Deep-nested lists are flattened via a pure recursive `flatten`
   (`default.nix:96-97`).
3. Anything with `outPath` (flake inputs, derivations) is unwrapped
   into a path.
4. Foreign import-tree objects nested inside the argument list have
   their **own** filters honored via `(x.filter filterf).files`,
   then their result list is spliced back in. See test
   `"test can take other import-trees as if they were paths"`
   (`tests.nix:195-207`).
5. If the argument is an explicit **file** (not a directory), the
   filter is *ignored*  -  the file is included as-is. This matters
   for mixing manual imports (see `examples.mdx:97-104`).
6. `pathFilter` is applied to a *relativized* path
   (`relativize = file: removePrefix dir (toString file)`,
   `default.nix:100-103`), so infix/regex tests operate on paths
   relative to the directory root, not absolute store paths. This is
   the escape hatch that keeps `/nix/store/xxx-source/...` prefixes
   from polluting user filters.
7. `listDirFilesRecursive` (`default.nix:127-136`) is a
   `builtins.readDir`-only re-implementation of
   `lib.filesystem.listFilesRecursive`  -  no dependency on nixpkgs.

## 5. `flake.nix`  -  how it wires into the flake ecosystem

Complete file (`gh api repos/denful/import-tree/contents/flake.nix`):

```nix
{
  outputs = _: import ./.;
}
```

That is the entire flake. `outputs` ignores its `self`/`inputs`
argument and returns whatever `default.nix` returns, unwrapped. So
`inputs.import-tree` in a consumer flake is *directly* the callable
attrset built in `default.nix`. No `packages`, no `lib`, no
`overlays`, no per-system wrapping. Any consumer treating
`inputs.import-tree.foo` as a system-scoped output is wrong; every
method is at the top level.

Because the flake has no `inputs = { ... }` block, it introduces
**zero transitive flake inputs** into any consumer's lock file.
Verified against `~/ghq/github.com/Dauliac/nix-oci/flake.lock`: the
`"import-tree"` node contains `locked` + `original` only  -  no
`inputs` key.

## 6. Working example: `nix-oci`

Consumer: `~/ghq/github.com/Dauliac/nix-oci`. Import-tree call sites
in the non-worktree tree (from `grep -rn "import-tree" ... --include='*.nix'`):

- `flake.nix:15-17`  -  declares the flake input:

  ```nix
  import-tree = {
    url = "github:denful/import-tree";
  };
  ```

- `flake.nix:42`  -  makes it available as a module arg:

  ```nix
  _module.args.import-tree = inputs.import-tree;
  ```

  (Used so downstream perSystem / module code can `{ import-tree, ... }: ...`
  destructure it without re-plumbing `inputs`.)

- `nix/flake-module.nix:9-17`  -  the public flake module:

  ```nix
  inputs:
  {
    lib,
    config,
    ...
  }:
  {
    imports = [
      inputs.nix-lib.flakeModules.default
      inputs.flake-parts.flakeModules.modules
      # Auto-discover all modules using import-tree
      (inputs.import-tree ./modules)
    ];
    ...
  }
  ```

  This is the canonical `imports = [ (import-tree ./modules) ]`
  idiom from `README.md:41-43`, wrapped inside another flake-parts
  module.

- `nix/module.nix:8-15`  -  the same idiom applied to a subtree:

  ```nix
  { inputs, ... }:
  {
    imports = [
      (inputs.import-tree ./modules/deploy)
    ];

    config.flake.modules.flake.nix-oci = import ./flake-module.nix inputs;
    config.flake.modules.flake.nix-oci-test = import ./test-flake-module.nix inputs;
  }
  ```

- `nix/test-flake-module.nix:9-13`  -  same, for a testing subtree:

  ```nix
  inputs: {
    imports = [
      (inputs.import-tree ./modules/oci/testing)
    ];
  }
  ```

- `nix/examples.nix:22-34`  -  uses `.filterNot` to prune expensive
  example containers from a shared tree without editing the tree
  itself:

  ```nix
  {
    inputs,
    lib,
    ...
  }:
  let
    exampleTree = inputs.import-tree.filterNot (
      path: lib.any (pattern: lib.hasInfix pattern path) excludes
    );
  in
  {
    imports = [ (exampleTree ../examples/flake) ];
  }
  ```

  Note the fluent style: `.filterNot` returns a configured import-tree,
  which is then called with a path  -  matching the "chained then
  applied" pattern from `combinator.mdx`.

- `nix-oci` uses `_`-prefixed helper files pervasively so
  import-tree skips them: `nix/modules/oci/pipeline/_step-spec.nix`,
  `nix/modules/oci/lib/_mkProbeToolBundle.nix`,
  `nix/modules/oci/testing/_option-test-spec.nix`,
  `nix/modules/oci/testing/_python-gen.nix`,
  `nix/modules/_nixos-oci/nix-lib-declarations.nix`, etc. All carry
  a comment like:

  > "Prefixed with _ so import-tree does not auto-import this as a module."
  > (`nix/modules/oci/testing/_option-test-spec.nix:7`)

  This is the `/_` convention from `filtering.mdx:9-15`.

## 7. The Dendritic Pattern

Two upstream references:

### 7.1 Per `mightyiam/dendritic/README.md` (master branch)

Complete file exists at `~/.tmp-research/mightyiam-dendritic-README.md`
(220 lines). Key points, verbatim citations:

- Definition (`mightyiam/dendritic/README.md:5`):

  > "A Nixpkgs module system usage pattern"

- Core rule (`mightyiam/dendritic/README.md:60-64`):

  > "In the dendritic pattern every Nix file except for entry points
  > such as `default.nix` and `flake.nix` is a module of the
  > top-level configuration. In other words, every Nix file that
  > isn't an entry point is a Nixpkgs module system module that is
  > imported directly into the evaluation of the top-level
  > configuration."

- Every top-level module (`mightyiam/dendritic/README.md:65-69`):

  > "- implements a single feature
  > - ...across all configurations that that feature applies to
  > - is at a path that serves to name that feature"

- Lower-level modules (NixOS, home-manager, nix-darwin) live as
  *option values* inside the top-level config, exploiting
  `deferredModule` value merging
  (`mightyiam/dendritic/README.md:71-94`).

- Why import-tree matters here
  (`mightyiam/dendritic/README.md:105-111`):

  > "### Automatic importing
  > Since all non-entry-point files are top-level modules and their
  > paths convey meaning only to the author, they can all be
  > automatically imported using a trivial expression or [a small
  > library](https://github.com/vic/import-tree)."

  (Note the outdated `vic/import-tree` URL  -  same repo, now hosted
  under `denful/`.)

- Anti-patterns explicitly called out
  (`mightyiam/dendritic/README.md:143-220`):
  - Not declaring options for module storage.
  - Passing values via `specialArgs` instead of top-level config.
  - Lower-level module name proliferation.
  - Fanaticism (mixing `callPackage` files with `.pkg.nix` suffix is
    a reasonable exception).
  - `enable` options  -  since importing a module in dendritic style
    means "this feature is on", `mkEnableOption` becomes
    unnecessary.

### 7.2 Per import-tree's own `guides/dendritic.mdx`

`docs/src/content/docs/guides/dendritic.mdx:10-22`:

> "The Dendritic pattern is a convention where each file is a
> self-contained Nix module. Rather than large monolithic files,
> your configuration becomes a directory tree where each concern
> lives in its own file."

Benefits listed (`dendritic.mdx:36-40`):

> "- Locality  -  each concern in its own file, easy to find and modify
> - Composability  -  add or remove features by adding or removing files
> - No boilerplate  -  `import-tree` handles the wiring
> - Git-friendly  -  file additions don't cause merge conflicts in import lists
> - Discoverable  -  directory structure documents the system"

The `/_` convention (`dendritic.mdx:68-88`)  -  underscore-prefixed
directories are reserved for helpers that must not be auto-imported;
you `let helpers = import ./_lib/helpers.nix;` them explicitly.

### 7.3 How import-tree implements dendritic

The pattern is not enforced  -  import-tree is agnostic. It just
provides the "trivial expression" (`mightyiam/dendritic`'s wording)
that makes the pattern ergonomic:

- The default filter (`.nix` files, no `/_` in path) matches
  dendritic conventions exactly.
- The returned module has `imports = <all files>` at the top level,
  which is what dendritic wants (every file participates in the
  top-level `evalModules`).
- `.addScoped` supports the dendritic "share values via top-level
  config" style without threading `specialArgs`.
- Foreign import-tree objects nested inside import lists lets you
  compose dendritic libraries (e.g. nix-lib ships a curated tree,
  consumer merges it with their own tree).

## 8. Composition with `flake-parts.lib.mkFlake`

Verbatim from `README.md:33-44`:

```nix
# flake.nix
{
  inputs.import-tree.url = "github:denful/import-tree";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; }
   (inputs.import-tree ./modules);
}
```

What happens under evaluation:

1. `inputs.import-tree` is the callable attrset from `default.nix`.
2. `inputs.import-tree ./modules` invokes `functor` with `./modules`.
   `./modules` is neither a function nor a module-eval attrset, so
   the `else` branch runs: `perform self.__config ./modules`
   (`default.nix:185`). This returns the lambda module
   `_: { imports = <list-of-files-from-./modules>; }`
   (`default.nix:20-27`).
3. `mkFlake { inherit inputs; } <module>` in flake-parts takes any
   flake-parts module value. Because import-tree's return value is a
   lambda that takes one argument and produces `{ imports = ...; }`,
   it fits the flake-parts module interface directly.
4. flake-parts calls the lambda inside its own `evalModules`. At that
   point `leaves ./modules` runs  -  `builtins.readDir` walks the tree,
   the filter/map chain is applied, and the final flat list of paths
   populates `imports`. Each of those files is then itself evaluated
   as a flake-parts module.

So `import-tree ./modules` is *evaluated during our flake's
evaluation*, not at fetch time. The output of that evaluation is a
plain attrset whose `imports` field holds Nix paths inside our
flake's source tree (paths like `/nix/store/hash-source/modules/foo.nix`
once realised).

`nix-oci` uses a variation: it puts `(inputs.import-tree ./modules)`
inside an inner `imports = [ ... ]` of a bespoke flake-parts module
(`nix/flake-module.nix:11-17`). This is fine because flake-parts
modules recursively resolve nested `imports`. The tree walk still
runs during the enclosing `mkFlake` evaluation.

## 9. The critical question  -  runtime input or build-time only?

**Question**: does import-tree need to remain a runtime input for
consumers of a flake that uses it, or is it purely build-time? After
`mkFlake` evaluates, are the discovered module paths inlined into the
resulting flake outputs, or do consumers who import our flake also
transitively pull import-tree?

**Answer**: import-tree is *only invoked at flake-evaluation time*.
Nothing about the produced flake outputs references import-tree at
runtime. But the flake input graph is a separate concern from the
evaluated output graph, so there are two distinct sub-questions.

### 9.1 Is import-tree code executed by downstream consumers?

**No.** Once *our* flake evaluates:

- `inputs.import-tree ./modules` returns
  `_: { imports = [ /nix/store/xxx-source/modules/a.nix
  /nix/store/xxx-source/modules/b.nix ... ]; }`.
- flake-parts / evalModules resolves the lambda immediately in the
  same evaluation.
- The `flake.<attr>` outputs (nixosModules, packages, etc.) that we
  export are the *results* of module evaluation. They are attrsets
  of derivations, options, and further module functions  -  none of
  which retain a reference to the import-tree callable.

A downstream flake that does `imports = [ inputs.nix-lib.flakeModules.default ]`
never causes import-tree code to run. Our module output already
contains the fully materialized `imports` list of concrete paths.

Note however: **if we re-export our modules as functions of
`inputs`** (which nix-oci does not; it materializes them via the
outer `mkFlake`), then the tree walk defers until the consumer's
evaluation. The idiom `inputs.import-tree ./modules` inside a flake
module that is *itself only evaluated in the consumer's `mkFlake`*
means the consumer runs the tree walk. In `nix-oci`, `nix/flake-module.nix`
is exported at `flake.modules.flake.nix-oci` (see `nix/module.nix:13`)
and consumers `imports = [ inputs.nix-oci.flake.modules.flake.nix-oci ]`
 -  but `inputs.import-tree` is passed through `_module.args.import-tree`
(`flake.nix:42`), so **the consumer's flake-parts evaluation calls
import-tree**. The consumer therefore must have import-tree
resolvable at evaluation time.

**Two idioms, two very different implications:**

- **Materialize at library-flake eval time**: Do the tree walk *inside*
  our own `mkFlake` (the `outputs = inputs: mkFlake { inherit inputs; }
  (inputs.import-tree ./modules);` pattern from `README.md:41-43`).
  Then `flake.<outputs>` are already flat. Consumers do not need
  import-tree. This is what the README recommends and what `nix-oci`
  does at its **root** flake.

- **Defer to consumer eval time**: Ship a flake module that itself
  contains `(inputs.import-tree ./modules)`. The consumer's
  `mkFlake` needs `inputs.import-tree` to be resolvable. This is
  what `nix-oci/nix/flake-module.nix` does  -  and the reason
  `nix-oci`'s consumers must have import-tree in their input graph,
  either directly or via `follows`. `nix-oci` handles this by
  making its `flake-module` a **function of `inputs`**, and
  consumers wire it via `import ./flake-module.nix inputs`, which
  captures the *nix-oci* flake's `inputs.import-tree`. So the
  consumer never sees import-tree as their own input, but they do
  transitively pull it via `nix-oci`'s lock.

### 9.2 Is import-tree in the consumer's transitive `flake.lock`?

**Yes, if we declare it as a flake input.** Nix flakes list every
transitive input in the consumer's lock regardless of whether the
consumer uses the referenced code. `nix flake metadata` on `nix-oci`
(or `~/ghq/github.com/Dauliac/nix-oci/flake.lock:import-tree`) shows
`import-tree` present. Any downstream flake with
`inputs.nix-oci.url = "..."` will have `import-tree` under
`inputs.nix-oci.inputs.import-tree` in their own lock.

**Cost of that transitive entry:**
- Zero further transitive inputs (`import-tree`'s flake declares
  none). One tarball fetch (~15 KB). One `flake.lock` node.
- No `nixpkgs` or `flake-parts` transitive weight  -  import-tree
  really is a leaf.

### 9.3 How to hide it from consumers

Three options, ranked by isolation:

1. **Vendor `default.nix`**  -  copy the ~268-line file into
   `nix-lib`, tree it as `nix-lib/lib/import-tree.nix`, and never
   declare a flake input. Because `default.nix` uses only pure
   `builtins` (no `nixpkgs.lib`), vendoring is essentially free.
   Import at the top of our library:
   `let importTree = import ./lib/import-tree.nix; in ...`. Consumers
   see zero trace. Licence is MIT (`gh api repos/denful/import-tree`
   → `license.spdx_id: "MIT"`), so vendoring is compatible with any
   project.
   Downside: manual updates. But the API is small and stable.
2. **Add `import-tree` as a `flake.nix` input but do *all* tree
   walks at our own flake's eval time.** The consumer's lock will
   still show it as a transitive entry, but no code runs on the
   consumer side. This is the middle path. Fine when consumers are
   fine with a single extra lock entry.
3. **Expose it as an input the consumer must supply / follow.** The
   nix-oci pattern. Consumers can `follows` it to unify versions,
   but they must have it in their flake input graph. Highest
   coupling.

### 9.4 Verifying purity

From `default.nix`, the tree reader uses:

- `builtins.readDir`, `builtins.readFileType`, `builtins.filter`,
  `builtins.map`, `builtins.concatMap`, `builtins.attrNames`,
  `builtins.match`, `builtins.stringLength`, `builtins.substring`,
  `builtins.isPath`, `builtins.isString`, `builtins.isAttrs`,
  `builtins.isFunction`, `builtins.functionArgs`,
  `builtins.scopedImport`, `builtins.mapAttrs`, `builtins.warn`.

That is it. No `import <nixpkgs>`, no `lib.filesystem.*`, no
overlays, no derivations built at eval time. Vendoring the file
imposes no version coupling on us.

## 10. Verbatim source (key excerpts)

For posterity so future readers do not need to refetch.

### 10.1 `default.nix` lines 143-232  -  the builder

```nix
callable =
  let
    initial = {
      # Accumulated configuration
      api = { };
      mapf = i: i;
      filterf = _: true;
      paths = [ ];
      scoped = { };

      __functor =
        config: update:
        let
          updated = update config;
          current = config update;
          boundAPI = builtins.mapAttrs (_: g: g current) updated.api;

          accAttr = attrName: acc: config (c: mapAttr (update c) attrName acc);
          mergeAttrs = attrs: config (c: (update c) // attrs);
        in
        boundAPI
        // {
          __config = updated;
          __functor = functor;

          filter = filterf: accAttr "filterf" (and filterf);
          filterNot = filterf: accAttr "filterf" (andNot filterf);
          match = regex: accAttr "filterf" (and (matchesRegex regex));
          matchNot = regex: accAttr "filterf" (andNot (matchesRegex regex));
          map = mapf: accAttr "mapf" (compose mapf);
          addScoped = attrs: accAttr "scoped" (s: s // attrs);
          addPath = path: accAttr "paths" (p: p ++ [ path ]);
          addAPI = api: accAttr "api" (a: a // api);

          withLib = _lib: mergeAttrs { };
          initFilter = initf: mergeAttrs { inherit initf; };
          pipeTo = pipef: mergeAttrs { inherit pipef; };
          leaves = mergeAttrs { pipef = i: i; };
          leafs =
            builtins.warn "import-tree.leafs has been deprecated. Use import-tree.leaves instead."
              (mergeAttrs { pipef = i: i; });

          result = current [ ];
          files = current.leaves.result;
          new = callable;
        };
    };
  in
  initial (config: config);

in
callable
```

### 10.2 `default.nix`  -  vendored nixpkgs helpers

`default.nix:83-136`  -  behavior-identical `flatten`, `removePrefix`,
`hasSuffix`, `hasInfix`, `listDirFilesRecursive`, `compose`, `and`,
`andNot`, `matchesRegex`, `mapAttr`, `isPathLike`, `hasOutPath`,
`isImportTree`, `inModuleEval`. Every one implemented with pure
`builtins`.

### 10.3 `tests.nix`  -  API coverage that doubles as documentation

Fully retrieved at `~/.tmp-research/it-tests.nix` (382 lines,
32 named test cases). Structure: `nix-unit` style
`{ suiteName."description" = { expr = ...; expected = ...; }; }`.
Every API method has at least one test:

- `leaves`: 4 tests (default filter, hidden dirs, single-file root,
  backward-compat withLib no-op).
- `filter`: 3 tests (predicate composition).
- `match`/`matchNot`: 4 tests (regex, composition with filter).
- `map`: 3 tests (transform, compose with filter, compose with map).
- `addPath`: 3 tests (prepend, multi-call, identity vs. direct
  list argument).
- `new`: 1 test (state clear).
- `initFilter`: 2 tests (non-nix file discovery, non-path items).
- `addAPI`: 3 tests (extension, preservation, late binding).
- `pipeTo`: 1 test (pipe into length).
- `import-tree`: 9 tests (single-file argument, module-eval
  integration, outPath/attrset arguments, nested import-trees,
  submodule use, hidden-path composition).
- `scoped`: 4 tests (attr injection, builtins scoped, nixPath
  hermeticity, custom builtins overlay).
- `combinator`: 1 test (chained combinator syntax).

This test file is a full-fidelity spec of expected behavior and is
the best single artefact to consult when adopting the library.

## 11. Suitability for nix-lib  -  quick decision-relevant facts

- **Zero-input flake** (`flake.nix` = 3 lines, no `inputs`
  declaration). Adopting it costs one lock entry with no downstream
  fan-out.
- **Single-file** (`default.nix`, 268 lines). Trivial to vendor if we
  want to hide it entirely.
- **Pure `builtins` implementation**  -  no nixpkgs `lib` dependency at
  runtime (`.withLib` is a documented no-op kept for back-compat,
  `default.nix:218-220`). Safe to run under `evalModules` in any
  context.
- **MIT-licensed** (`gh api repos/denful/import-tree` →
  `license.spdx_id: "MIT"`, and `LICENSE` file at repo root, size
  11 357 bytes).
- **Stable, tested API**  -  `tests.nix` covers every method; changes
  since the vic → denful rename have added `.pipeTo`, hardened
  `.addScoped`, made `.withLib` a no-op, and deprecated `.leafs`
  (`default.nix:225-228`).
- **Idiomatic composition**  -  `.filter`, `.map`, `.addAPI` compose
  cleanly. The `nix-oci/examples.nix` use case (dynamically prune
  example modules via `.filterNot`) is a good template for the
  kinds of filter-first-then-apply patterns nix-lib would want.
- **Dendritic-agnostic**  -  nothing forces the dendritic pattern.
  Using import-tree on a subtree of modules alongside conventional
  imports is fine and demonstrated by `nix-oci`.

## 12. Where the primary sources live (URLs)

- Repo root: <https://github.com/denful/import-tree>
- Tree at HEAD: `gh api repos/denful/import-tree/git/trees/HEAD?recursive=1`
  (SHA `eb1b52eaecc57f7c136d07ae8a93e724dfecac46` at time of research)
- `default.nix`: <https://github.com/denful/import-tree/blob/main/default.nix>
- `flake.nix`: <https://github.com/denful/import-tree/blob/main/flake.nix>
- `tests.nix`: <https://github.com/denful/import-tree/blob/main/tests.nix>
- `README.md`: <https://github.com/denful/import-tree/blob/main/README.md>
- Docs site source: <https://github.com/denful/import-tree/tree/main/docs/src/content/docs>
  - `overview.mdx`, `motivation.mdx`,
    `getting-started/quick-start.mdx`,
    `reference/api.mdx`, `reference/examples.mdx`,
    `guides/filtering.mdx`, `guides/mapping.mdx`,
    `guides/custom-api.mdx`, `guides/combinator.mdx`,
    `guides/dendritic.mdx`, `guides/outside-modules.mdx`.
- Rendered docs (referenced, not the source of truth):
  <https://import-tree.oeiuwq.com>
- Dendritic pattern spec: <https://github.com/mightyiam/dendritic>
- Working consumer under study:
  `/home/juliendauliac/ghq/github.com/Dauliac/nix-oci` (call sites
  enumerated in section 6).
- All fetched files staged at
  `/home/juliendauliac/ghq/github.com/Dauliac/nix-lib/.tmp-research/`
  during this research.
