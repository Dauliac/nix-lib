# `denful/flake-file` primary-source research

Scope: research the `denful/flake-file` Nix library from primary sources
only (upstream docs page, README, source tree, LICENSE, release history,
and two working consumers). Goal: enough depth for nix-lib to decide
whether to adopt it as an internal tool, vendor it, or skip it.

All citations point at the upstream repo `denful/flake-file` (branch
`main`), the docs site at `https://denful.dev/ecosystem/flake-file/` and
`https://flake-file.denful.dev`, or the two consumer repos
(`denful/checkmate`, `denful/dendrix`) verified via `gh api` at the time
of research (2026-09-26).

Note on fork history: the generated flake.nix header in the docs and in
consumer repos still occasionally reads
`# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.`
The org rename to `denful/*` landed on 2026-09-11 in commit
`chore: vic/flake-file -> denful/flake-file (#135)`. `vic` and `denful`
are the same maintainer; every input URL in this document uses the new
canonical `github:denful/flake-file` form, which is also what the current
`main` branch emits.

---

## 1. What it does, one sentence

> "flake-file lets you generate a clean, maintainable `flake.nix` from
> Nix module options. Use the *real* Nix language to define your
> inputs." (`README.md:18`,
> `https://github.com/denful/flake-file/blob/main/README.md`)

Concretely, `flake-file` inverts the ownership of `flake.nix`. Instead
of humans writing the file directly (with all the flake DSL
restrictions: no `import`, no `lib.mkDefault`, no `let` bindings at
top-level, no computed input URLs), users declare inputs and metadata
through a typed Nix module system schema. A generator app
(`nix run .#write-flake`) then serialises that eval'd config back to a
`flake.nix` on disk. A companion `flake check` verifies the on-disk file
matches what the modules would regenerate.

## 2. Repo layout

`gh repo view denful/flake-file` says 155 stars, Apache-2.0, default
branch `main`, latest release `v0.6.0` (2026-04-14). Six releases so far
(`v0.4.0` 2026-02-28, `v0.5.0` 2026-03-07, `v0.6.0` 2026-04-14; earlier
ones prior). Active as of this month: last commit 2026-09-11.

Top-level tree:

| Path | Purpose |
| --- | --- |
| `flake.nix` | 3 lines, `{ outputs = _: import ./modules; }`. |
| `default.nix` | 1 line, `import ./modules/bootstrap`. Used by the `nix-shell` bootstrap. |
| `modules/` | All library code (see below). |
| `templates/` | Eight starter templates (`minimal`, `default`, `parts`, `dendritic`, `npins`, `flakeless-parts`, `unflake`, `tack`). |
| `docs/` | Astro / Starlight site source (`astro.config.mjs`, `pnpm-lock.yaml`, `src/`). |
| `dev/` | The library's own dev shell + test infra + private `_lib` used by generators. |
| `LICENSE` | Apache License 2.0, verbatim. |

The public `modules/` tree (line counts from `wc -l`):

```
modules/default.nix              122   flakeModules aggregator + templates map
modules/write-flake.nix          205   write-flake app + check-flake-file check (core)
modules/write-inputs.nix          89   debug: dump inputs to a file
modules/write-lock.nix            42   flake.lock regen helper
modules/flake-parts.nix            9   integration for flake-parts consumers
modules/flake-options.nix         27   options for non-flake-parts consumers
modules/flakeless-parts.nix       19   npins + flake-parts glue
modules/auto-follow.nix            4   flip auto-follow on by default
modules/import-tree.nix            4   default-pin the import-tree input
modules/lib.nix                    1   re-export lib entry point

modules/options/                       (typed schema, 11 files, 452 lines total)
  default.nix                     14   options aggregator
  flake-file.nix                  53   .description + .nixConfig
  inputs.nix                     135   the full Input schema (url/type/owner/repo/ref/rev/follows/inputs/...)
  outputs.nix                     49   the Output schema (default/flake-file/flake-module/import-tree/flake-parts/dendritic)
  auto-follow.nix                  4   enable flag
  prune-lock.nix                  73   generic .prune-lock.{enable,program} pair
  do-not-edit.nix                 22   configurable header comment
  formatter.nix                   17   default pkgs.nixfmt
  style.nix                       63   separators + attribute sort priorities
  write-hooks.nix                 35   ordered list of write-time hooks
  check-hooks.nix                 40   ordered list of check-time hooks

modules/prune-lock/
  allfollow.nix                   14   plug spikespaz/allfollow as prune-lock.program
  nix-auto-follow.nix             18   plug fzakaria/nix-auto-follow as prune-lock.program
  _nothing.nix                     8   no-op default

modules/dendritic/                     (opt-in preset, 51 lines total)
  default.nix                      9   aggregator
  dendritic.nix                   18   import-tree flakeModule + dendritic outputs preset
  basic.nix                       12   (not read in this pass)
  nixpkgs.nix                      8
  systems.nix                      4
```

Total public module code, excluding backend variants (`npins/`, `tack/`,
`unflake/`, `flake-parts-builder/`, `bootstrap/`) and the private
`dev/modules/_lib`: roughly **522 lines** across 10 files at
`modules/*.nix`, plus **452 lines** across 11 files in `modules/options/`.

The private serialiser lives in `dev/modules/_lib/default.nix` (272
lines) and is imported through a relative path
`./../dev/modules/_lib` from `write-flake.nix` and `write-inputs.nix`
(see `write-flake.nix:8`). That path is baked into the consumed
derivation, so downstream users get the whole `dev/_lib` for free at
`inputs.flake-file`.

## 3. flake.nix and inputs

`modules/flake.nix` in full:

```nix
{
  outputs = _: import ./modules;
}
```

Zero declared inputs. `flake-file` itself is a **leaf input** for
consumers, exactly like `import-tree`: any `flake.lock` node for
`flake-file` has no `"inputs"` key.

The library's own dev flake (`dev/flake.nix`) uses flake-parts +
import-tree and pulls seven inputs (`devshell`, `flake-parts`,
`import-tree`, `nix-auto-follow`, `nix-unit`, `nixpkgs`, `treefmt-nix`),
but that dev tree is not part of the outputs a consumer sees.

## 4. Public API surface  -  full signatures

The public entry point is `inputs.flake-file` which resolves to the
attrset built in `modules/default.nix`:

```nix
{
  inherit flakeModules templates lib;
}
```

### 4.1 `flakeModules`

Verbatim from `modules/default.nix:2-17`:

```nix
flakeModules = {
  inherit
    flake              # for non-flake-parts flakes
    default            # for flake-parts flakes (keep as default for compatibility)
    allfollow
    nix-auto-follow
    auto-follow
    dendritic
    import-tree
    npins
    flakeless-parts
    unflake
    tack
    flake-options
    ;
};
```

Composition (same file, lines 20-69):

- `flake.imports = [ base flake-options ./write-flake.nix ]`  -  the
  non-flake-parts backend. Consumer's outputs function evals modules
  themselves via `lib.evalModules`.
- `default.imports = [ base ./write-flake.nix ./flake-parts.nix ]`  -
  the flake-parts backend. `flake-parts.nix` (9 lines) wires
  `packages.write-flake` and `checks.check-flake-file` into every
  `perSystem`.
- `base.imports = [ ./options ./write-inputs.nix ./write-lock.nix ]`  -
  shared core.
- `allfollow` and `nix-auto-follow` are drop-in `prune-lock.program`
  configurations (`modules/prune-lock/allfollow.nix`,
  `modules/prune-lock/nix-auto-follow.nix`). Each pins its own input
  URL (`github:spikespaz/allfollow`,
  `github:fzakaria/nix-auto-follow`) via `lib.mkDefault`.
- `auto-follow` = `{ flake-file.auto-follow.enable = lib.mkDefault true; }`.
  Turning it on requires `pkgs.flake-edit >= 0.3.5` at eval time
  (`write-flake.nix:127`, hard `throw` otherwise).
- `import-tree` = `{ flake-file.inputs.import-tree.url = lib.mkDefault "github:denful/import-tree"; }`.
- `dendritic` imports `./dendritic/*.nix`, which pins flake-parts, adds
  the `import-tree` flakeModule, and sets `flake-file.outputs = "dendritic"`.
- `npins`, `flakeless-parts`, `unflake`, `tack` are the stable-Nix /
  non-flake backends (out of scope for nix-lib since we are flake-native).

There is also a helper on `lib.flakeModules.flake-parts-builder path`
that returns a flake-parts module wired through
`flake-parts-lib.importApply` (`modules/default.nix:71-78`).

### 4.2 The typed `flake-file.inputs` schema

`modules/options/inputs.nix:32-130` defines every input attribute a
flake can express, with per-attribute Nix types. Extract of the option
type (verbatim, condensed):

```nix
inputs-option = lib.mkOption {
  default = { };
  description = "Flake inputs";
  type = lib.types.lazyAttrsOf (lib.types.submodule {
    options = {
      url        = lib.mkOption { type = lib.types.str;  default = ""; };
      type       = lib.mkOption { type = lib.types.nullOr (lib.types.enum [
                     "indirect" "path" "git" "mercurial" "tarball"
                     "file" "github" "gitlab" "sourcehut"
                   ]); default = null; };
      submodules = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = null; };
      shallow    = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = null; };
      lfs        = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = null; };
      owner      = lib.mkOption { type = lib.types.str;  default = ""; };
      repo       = lib.mkOption { type = lib.types.str;  default = ""; };
      path       = lib.mkOption { type = lib.types.str;  default = ""; };
      id         = lib.mkOption { type = lib.types.str;  default = ""; };
      dir        = lib.mkOption { type = lib.types.str;  default = ""; };
      narHash    = lib.mkOption { type = lib.types.str;  default = ""; };
      rev        = lib.mkOption { type = lib.types.str;  default = ""; };
      ref        = lib.mkOption { type = lib.types.str;  default = ""; };
      host       = lib.mkOption { type = lib.types.str;  default = ""; };
      flake      = lib.mkOption { type = lib.types.bool; default = true; };
      follows    = follows-option;                 # nullOr str
      inputs     = inputs-follow-option;           # recursive attrs of { autoFollow, follows, inputs }
    };
  });
};
```

Two things that matter:

1. Every input attribute is `lib.mkOption`-backed, so consumers can use
   `lib.mkDefault`, `lib.mkForce`, `lib.mkIf`, priority arithmetic, and
   compose partial inputs from many separate `.nix` files. That is the
   whole point vs. hand-writing `flake.nix`.

2. The nested `inputs.<name>.inputs.<sub>.autoFollow` boolean
   (`inputs.nix:15-22`) is the hook that `flake-edit follow` reads to
   decide whether to auto-generate a `follows = "..."` link. Setting it
   false opts a sub-input out of auto-follow.

### 4.3 The `flake-file.outputs` schema

`modules/options/outputs.nix:1-49`. It is a single `str` option whose
`apply` maps well-known keywords to canned outputs bodies:

```nix
easyOutputs = {
  default      = ''inputs: import ./outputs.nix inputs'';
  flake-file   = ''inputs: (import ./flake-file.nix).outputs inputs'';
  flake-module = ''
    inputs:
      (inputs.nixpkgs.lib.evalModules {
        specialArgs = { inherit inputs; inherit (inputs) self; };
        modules = [ inputs.flake-file.flakeModules.flake  ./flake-file.nix ];
      }).config.outputs inputs
  '';
  import-tree  = ''
    inputs:
    (inputs.nixpkgs.lib.evalModules {
      specialArgs = { inherit inputs; inherit (inputs) self; };
      modules = [ (import-tree ./modules) ];
    }).config.outputs inputs
  '';
  flake-parts  = ''inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } ./modules'';
  dendritic    = ''inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)'';
};
```

If the string is not one of those keywords, it is embedded verbatim as
the outputs body. This is how `nix-lib`'s custom
`... // { lib = (result.lib or { }) // { inherit ... }; }` wrapper
could be represented (or not, see verdict).

### 4.4 The rest of `flake-file.*`

Discovered by grepping options across `modules/options/`:

| Option | Type | Default | Source |
| --- | --- | --- | --- |
| `flake-file.description` | `str` | `""` | `flake-file.nix:8-12` |
| `flake-file.nixConfig` | freeform attrs + typed `substituters`, `extra-substituters`, `trusted-public-keys`, `extra-trusted-public-keys` (list of str each) | `{ }` | `flake-file.nix:13-49` |
| `flake-file.inputs` | see 4.2 | `{ }` | `options/inputs.nix` |
| `flake-file.outputs` | `str` with keyword `apply` | `"default"` | `options/outputs.nix` |
| `flake-file.do-not-edit` | `str` with `apply` prefixing `#` | see below | `options/do-not-edit.nix` |
| `flake-file.formatter` | `pkgs -> package` | `pkgs: pkgs.nixfmt` | `options/formatter.nix` |
| `flake-file.style.sep.{flake,inputs,inputSchema,nixConfig}` | `str` | see `style.nix:26-31` | `options/style.nix` |
| `flake-file.style.sortPriority.{flake,inputs,inputSchema,nixConfig}` | `listOf str` | see `style.nix:33-61` | `options/style.nix` |
| `flake-file.auto-follow.enable` | `bool` enable | `false` | `options/auto-follow.nix` |
| `flake-file.prune-lock.enable` | `bool` enable | `false` | `options/prune-lock.nix` |
| `flake-file.prune-lock.program` | `pkgs -> exe`, called as `program flake.lock out.lock` | no-op | `options/prune-lock.nix` |
| `flake-file.write-hooks` | `listOf { index :: int; program :: pkgs -> package }` | `[]` | `options/write-hooks.nix` |
| `flake-file.check-hooks` | same shape as write-hooks | `[]` | `options/check-hooks.nix` |
| `flake-file.apps` | `lazyAttrsOf (pkgs -> package)` | `{ write-flake, write-inputs, bootstrap }` | `write-inputs.nix:54-58` |
| `flake-file.intoPath` | `str` (internal) | `"."` | `write-inputs.nix:60-65` |
| `flake-file.preProcess` | `raw -> raw` | `lib.id` | `write-inputs.nix:83-87` |
| `flake-file.pkgs` | `raw` | `import <nixpkgs> {}` | `write-inputs.nix:48-52` |

Default `do-not-edit` header (`options/do-not-edit.nix:4-7`):

```nix
default = ''
  # DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
  # Use `nix run .#write-flake` to regenerate it.
'';
```

Default style sort priority for the whole flake
(`options/style.nix:34-40`):

```nix
sortPriority.flake = [
  "description"
  "outputs"
  "nixConfig"
  "inputs"
];
```

That is why every generated `flake.nix` from flake-file consistently
puts `outputs` before `inputs`, which is the opposite of what Nixpkgs'
`nix flake` docs use.

### 4.5 The generator itself

`modules/write-flake.nix` (205 lines) is the beating heart:

- Reads `config.flake-file.inputs`, passes through
  `flake-file.preProcess`, and if `auto-follow.enable` also merges
  automatic follows discovered by reading
  `${inputs.self}/flake.nix` at eval time
  (`write-flake.nix:22-29`).
- Serialises to a Nix expression via
  `nixCode { expr = ...; styles = [...]; }` from the private
  `dev/modules/_lib` (`write-flake.nix:8-15`).
- Wraps the result in `stdenvNoCC.mkDerivation` that runs
  `flake-file.formatter pkgs` on the output
  (`write-flake.nix:99-112`).
- Exposes `packages.write-flake` as a `writeShellApplication` that
  `cmp -s` against the existing `flake.nix`, overwrites only on diff,
  optionally runs `nix flake lock` + `flake-edit follow` when
  `auto-follow.enable = true`, then runs every hook in
  `write-hooks` sorted by `index` (`write-flake.nix:142-167`).
- Exposes `checks.check-flake-file` as a `runCommandLocal` that
  `diff -u ${self}/flake.nix <regenerated>` and runs
  `check-hooks` (`write-flake.nix:169-195`).

`auto-follow` requires `pkgs.flake-edit >= 0.3.5` at build time
(`write-flake.nix:126-134`) or `throw`s. It is opt-in.

### 4.6 `templates` and `lib`

`templates` (`modules/default.nix:80-118`) exposes eight templates
addressable by `nix flake init -t github:denful/flake-file#<name>`:
`default`, `minimal`, `npins`, `flakeless-parts`, `unflake`, `tack`,
`dendritic`, `parts`. Read via
`nix flake show github:denful/flake-file#templates`.

`lib` currently exposes just one helper,
`lib.flakeModules.flake-parts-builder` (see 4.1). Not much surface.

## 5. Real-world consumers

### 5.1 `denful/dendrix`  -  the flagship

`gh api repos/denful/dendrix`: 137 stars,
`https://github.com/denful/dendrix`. Its `flake.nix` in full:

```nix
{
  outputs = inputs: import ./. inputs;
  inputs.import-tree.url = "github:vic/import-tree";
  inputs.nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
}
```

Notable: `dendrix` itself is *not* generated by `flake-file`. Only two
inputs, hand-written. `flake-file` shows up further down the dependency
graph as an internal implementation detail, not as the visible top
level. This is a data point that says "for a library flake, the
top-level flake.nix can stay hand-written even inside the ecosystem".

### 5.2 `denful/checkmate`  -  the more typical case

`gh api repos/denful/checkmate`: 18 stars, "A flake checker (treefmt &
nix-unit) for testing other flakes with zero dependencies". Its
`flake.nix` (verbatim):

```nix
# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
      url = "github:hercules-ci/flake-parts";
    };
    import-tree.url = "github:vic/import-tree";
    nix-unit = {
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:nix-community/nix-unit";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-lib.follows = "nixpkgs";
    systems.url = "github:nix-systems/default";
    target.url = "github:vic/checkmate?dir=templates/success";
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };

}
```

Nine inputs, alphabetically sorted, attributes inside each input sorted
by the schema (`type`, `host`, `url`, `owner`, `repo`, `path`, `id`,
`dir`, `narHash`, `rev`, `ref`, `shallow`, `submodules`, `lfs`,
`flake`, `follows`, `inputs`). Header is the generator's default
`DO-NOT-EDIT` comment.

`modules/flakeModule.nix` in checkmate shows the actual configuration
pattern:

```nix
{
  flake.flakeModule =
    { inputs, lib, ... }:
    {
      imports = [
        (inputs.flake-file.flakeModules.dendritic or { })
        (inputs.import-tree ./checkmate)
      ];

      flake-file.inputs.checkmate = {
        url = lib.mkDefault "github:vic/checkmate";
        inputs = {
          flake-file.follows   = "flake-file";
          flake-parts.follows  = "flake-parts";
          import-tree.follows  = "import-tree";
          nix-unit.follows     = "nix-unit";
          nixpkgs.follows      = "nixpkgs";
          nixpkgs-lib.follows  = "nixpkgs";
          systems.follows      = "systems";
          target.follows       = "target";
          treefmt-nix.follows  = "treefmt-nix";
        };
      };
    };
}
```

Reading: checkmate is opt-in dendritic (imports the `dendritic`
flakeModule which itself sets `flake-file.outputs = "dendritic"` and
brings `import-tree`). Every input is expressed as `lib.mkDefault` so
consumers of checkmate can override each URL. All the tedious
`inputs.X.follows = "Y"` plumbing is written once and then serialised
alphabetically by the generator into the top-level `flake.nix`.

The docs page also names `den` and `flake-aspects` as consumers.
`denful/den` (602 stars) is more extreme: its top-level `flake.nix` is

```nix
{
  outputs = _: import ./nix;
}
```

with no `inputs` block at all. All inputs are computed under `./nix/`.
That is the maximal application of the flake-file philosophy.

## 6. License, size, dependencies

- **License**: Apache License 2.0 (`LICENSE`, standard text). Compatible
  with nix-lib (BSD-like / no known conflict).
- **Runtime dependency of consumers**: exactly one flake input,
  `flake-file`, which is a leaf (no transitive `flake.lock` growth from
  adopting it). Confirmed by `modules/flake.nix` having no `inputs`.
- **Eval-time deps** (only when actually running `write-flake` or
  `check-flake-file`): `pkgs.nixfmt` (default formatter),
  `pkgs.diffutils`, `pkgs.nix`. If `auto-follow.enable = true`, also
  `pkgs.flake-edit >= 0.3.5`. If `prune-lock` with the `allfollow`
  preset, `spikespaz/allfollow` (extra flake input). If `prune-lock`
  with `nix-auto-follow`, `fzakaria/nix-auto-follow` (extra flake
  input).
- **Public source size** (excluding backends nix-lib would not use):
  - `modules/*.nix` top level (flake + flake-parts backends only):
    **~522 lines**, dominated by `write-flake.nix` at 205 lines.
  - `modules/options/*.nix`: **452 lines** across 11 files.
  - Private serialiser `dev/modules/_lib/default.nix`: **272 lines**,
    imported by relative path from `write-flake.nix:8`.
  - Aggregate: **~1250 lines** of actually-loaded code for the
    flake-parts flavour, plus the templates and backend directories on
    disk but not in the eval closure.
- **Test infrastructure**: `dev/` contains `nix-unit` tests and
  bootstrap tests; not shipped to consumers.

## 7. Verdict for nix-lib

**Do not adopt flake-file for nix-lib's top-level `flake.nix`.** It is a
well-designed tool solving a real problem for the wrong kind of flake.

Reasoning:

1. **nix-lib is at the size/shape where flake-file is a net loss.**
   Current `flake.nix` is 42 lines with exactly two inputs
   (`flake-parts`, `nixpkgs-lib`) and one custom output wrapper (the
   `// { lib = ... // { inherit mkFlake evalLibModules mkSpecialArgsLib mkLib mkAdapter withLib; }; }`
   suffix at lines 21-31). flake-file's typed input schema pays off when
   you have many inputs and many `follows` clauses (checkmate: 9
   inputs, 10 follows entries) that benefit from mechanical alphabetical
   sorting and `lib.mkDefault` overrides. With 2 inputs and 1 follows,
   the schema costs more than it saves.

2. **The custom outputs wrapper is awkward to express.** flake-file's
   `flake-file.outputs` option is a `str` with `apply` that maps a
   handful of keywords (`default`, `dendritic`, `flake-parts`, ...) to
   canned bodies. nix-lib's wrapper merges custom `lib.*` attributes
   after `mkFlake`'s result, which is not one of the keywords. You would
   embed it as a verbatim string literal, losing static analysis on the
   very code that is the point of the library. Compare
   `templates/minimal/flake.nix:5-17` vs. nix-lib's current
   `flake.nix:7-32`: the minimal template is longer than what we have
   now.

3. **Non-visible dependency chain.** Adopting flake-file adds one leaf
   flake input to nix-lib (fine, but real), plus a Nix-level dependency
   on `dev/modules/_lib/default.nix` living inside the flake-file
   source tree at a relative path from `write-flake.nix`. That path is
   an implementation detail of flake-file, not part of its public API,
   yet consumers get it in the eval closure whether they want it or
   not.

4. **No feature nix-lib needs is unique to flake-file.** The two
   consumer-visible benefits are (a) `lib.mkDefault` on input URLs and
   (b) modular composition of inputs across files. Neither applies to a
   2-input library flake. The `check-flake-file` idempotence guarantee
   is real, but nix-lib already has a formatting check via treefmt and
   the current 2 inputs do not drift.

5. **No partition/vendoring path is obviously worth it.** Unlike
   `import-tree` (a single 268-line file with a tiny, sharp API that
   made sense to vendor internally for the module-tree walking use-case
   inside nix-lib), flake-file is a generator app that only earns its
   keep when it owns the top-level `flake.nix`. There is no equivalent
   of the `import-tree` pattern where you can use half of it internally
   and keep the top-level flake.nix hand-written; the whole value is
   "own the top-level flake.nix".

If nix-lib grows to, say, 6+ inputs with non-trivial follows, or wants
to ship a flakeModule that consumers can extend to add their own
inputs, revisit this decision. Until then, the 42-line hand-written
flake.nix wins on legibility and zero-dependency terms.

## 8. Integration sketch (if verdict flips in future)

Kept short because the verdict is negative. If nix-lib decides later to
adopt flake-file:

**Files that change**

- `flake.nix`: becomes 3 lines, header + `outputs =
  inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)`,
  or a slight variant using `flake-file.outputs = "flake-parts"`. The
  inputs block is generated.
- `flake-file.nix` (new): a module that declares
  ```nix
  { lib, ... }: {
    imports = [ inputs.flake-file.flakeModules.default ];
    flake-file.inputs.flake-parts.url = lib.mkDefault "github:hercules-ci/flake-parts";
    flake-file.inputs.flake-parts.inputs.nixpkgs-lib.follows = lib.mkDefault "nixpkgs-lib";
    flake-file.inputs.nixpkgs-lib.url = lib.mkDefault "github:nix-community/nixpkgs.lib";
  }
  ```
- `modules/nix-lib-outputs.nix` or equivalent: gains the custom `lib`
  suffix, since the outputs body must be expressible as a string. In
  practice we would move the `mkFlake / evalLibModules / ...` re-export
  into a flakeModule that sets `flake.lib.<name> = ...` from within,
  eliminating the post-hoc `//` merge entirely. That is arguably an
  improvement independent of flake-file.

**What stays the same**

- Everything under `modules/nix-lib/**` (the library body), tests,
  README, everything downstream of the flake outputs.

**What breaks**

- Consumers pinning nix-lib by commit SHA are unaffected.
- Contributors need to know to run `nix run .#write-flake` after
  touching any input in `flake-file.nix`. CI needs
  `checks.check-flake-file` wired in (comes for free with the
  `default` flakeModule under flake-parts).
- The generated `flake.nix` will list `outputs` before `inputs`, which
  differs from convention. Cosmetic.

**Rough size of the change**: one new module (~20 lines), one edit to
`flake.nix` (42 -> ~3 lines), one edit to CI to run
`nix flake check` and expect `check-flake-file` to pass, one edit to
`modules/nix-lib-outputs.nix` to fold in the `lib.*` re-exports as a
proper `flake.lib` module. Reversible: `git revert` restores the
handwritten flake.

## 9. Sources

Primary sources consulted, all URLs verbatim:

- Docs landing page:
  `https://denful.dev/ecosystem/flake-file/` (WebFetched)
- Full docs site:
  `https://flake-file.denful.dev` (WebFetched, partial)
- Canonical repo:
  `https://github.com/denful/flake-file`
  - `README.md`:
    `https://github.com/denful/flake-file/blob/main/README.md`
  - `flake.nix`:
    `https://github.com/denful/flake-file/blob/main/flake.nix`
  - `default.nix`:
    `https://github.com/denful/flake-file/blob/main/default.nix`
  - `modules/default.nix`:
    `https://github.com/denful/flake-file/blob/main/modules/default.nix`
  - `modules/write-flake.nix`:
    `https://github.com/denful/flake-file/blob/main/modules/write-flake.nix`
  - `modules/write-inputs.nix`:
    `https://github.com/denful/flake-file/blob/main/modules/write-inputs.nix`
  - `modules/options/inputs.nix`:
    `https://github.com/denful/flake-file/blob/main/modules/options/inputs.nix`
  - `modules/options/outputs.nix`:
    `https://github.com/denful/flake-file/blob/main/modules/options/outputs.nix`
  - `modules/options/flake-file.nix`:
    `https://github.com/denful/flake-file/blob/main/modules/options/flake-file.nix`
  - `modules/options/{style,do-not-edit,formatter,auto-follow,prune-lock,write-hooks,check-hooks}.nix`
    (all under `.../modules/options/`)
  - `modules/prune-lock/{allfollow,nix-auto-follow,_nothing}.nix`
    (all under `.../modules/prune-lock/`)
  - `modules/dendritic/{default,dendritic}.nix`
    (all under `.../modules/dendritic/`)
  - `modules/{auto-follow,import-tree,flake-parts,flakeless-parts}.nix`
  - `modules/bootstrap/{default,inputs}.nix`
  - `templates/{minimal,default,dendritic,parts}/flake.nix`
  - `templates/minimal/flake-file.nix`
  - `templates/default/outputs.nix`
  - `LICENSE`
- Release history:
  `gh api repos/denful/flake-file/releases` (v0.4.0, v0.5.0, v0.6.0)
- Consumer 1 (dendrix):
  `https://github.com/denful/dendrix/blob/main/flake.nix`
- Consumer 2 (checkmate):
  `https://github.com/denful/checkmate/blob/main/flake.nix`,
  `.../modules/flakeModule.nix`,
  `.../modules/imports.nix`
- Consumer 3 (den):
  `https://github.com/denful/den/blob/main/flake.nix`
- nix-lib current state:
  `/home/juliendauliac/ghq/github.com/Dauliac/nix-lib/flake.nix`
