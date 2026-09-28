# Proposal: `flake.crossClassModules` primitive

Change ID: `cross-class-modules-primitive`
Status: draft
Date: 2026-09-28
Companion: design.md, tasks.md

## Summary

Add a single new file `modules/nix-lib/cross-class-modules.nix` that
declares one option `flake.crossClassModules` and derives
`flake.modules.<class>.<name>` from it. Auto-discovered by nix-lib's
existing import-tree (`internal-dendritic-import-tree`, landed), so
every consumer that already imports `nix-lib.flakeModules.default`
picks it up without additional wiring.

## Why

Downstream flake-parts projects (nix-oci is the immediate driver, but
the pattern is generic) frequently register the same module body
against several `flake.modules.<class>` keys. Today they write the
three-line epilogue by hand:

```nix
{
  flake.modules.nixos.foo       = mod;
  flake.modules.homeManager.foo = mod;
  flake.modules.systemManager.foo = mod;
}
```

Or worse, they hand-compose a super-module by triplicating the same
`imports = [ ... ]` list per class (nix-oci's `compose.nix` is 78
lines, three near-identical blocks; see nix-oci change
`declarative-cross-class-modules`).

Two alternatives were surveyed:

1. **`denful/flake-aspects`**. A small third-party library that
   transposes `flake.aspects.<name>.<class>` into
   `flake.modules.<class>.<name>`. Rejected during a proof of concept
   on nix-oci: the transpose primitive walks the aspect submodule's
   entire config with `lib.mapAttrsToList` and cannot distinguish
   declared option keys (`name`, `description`, `includes`, `provides`,
   `_`, `__functor`, `modules`, `resolve`) from freeform class cells.
   Result: `flake.modules` gets polluted with those names as fake
   top-level classes. Upstream has `has_issues: false`, so no
   remediation path. See nix-oci
   `.claude/research-cache/flake-aspects-README.md` for the full trace.

2. **Local helper in the consumer repo**. A ~10-line `import`-able
   helper works, but conflicts with the nix-lib convention (all libs
   live in nix-lib) and forces each consumer file to grow an `import
   ../../../../lib/foo.nix` line, which conflicts with the
   import-tree-only convention.

The right seam is: contribute a small option to nix-lib. Consumers
already have `nix-lib.flakeModules.default` imported at the top of
their flake, so the option becomes available with no additional wiring.
Each consumer file writes pure data:

```nix
{
  flake.crossClassModules.foo = {
    classes = [ "nixos" "homeManager" "systemManager" ];
    module  = { lib, ... }: { options... };
  };
}
```

The nix-lib aggregator computes `flake.modules.<class>.foo` for every
declared class. No output pollution, no manual imports, no function
calls from consumer sites.

## What Changes

- **New file** `modules/nix-lib/cross-class-modules.nix` declaring:
  - `options.flake.crossClassModules` (attrs-of submodule with
    `classes`, `module`, `includes`).
  - `config.flake.modules` derived from the option via `mkMerge`.
- **New test derivation** `checks.<system>.crossClassModulesTests`
  wired through the existing testing infrastructure (see
  `internal-dendritic-import-tree` for the discovery pattern).
  Assertions:
  - Symmetric case: three classes, one module, produces three entries.
  - Asymmetric case: `classes = [ nixos systemManager ]` produces two
    entries, none on `homeManager`.
  - `includes` case: composer with `includes = [ subA subB ]` where
    `subA.classes = [ nixos hm ]` and `subB.classes = [ nixos ]`
    produces per-class import lists filtered by each sub-module's own
    `classes`.
  - Interop fallback: composer's `includes` name is not present in
    `crossClassModules` (i.e. an existing hand-written
    `flake.modules.<class>.<name>` entry) - lookup falls back to the
    module tree and is included unconditionally.
- **README section** "Cross-class module registration" describing the
  option with one symmetric and one asymmetric example, plus a link
  to the design doc.
- **No breaking changes**: the option is opt-in; existing
  hand-written `flake.modules.<class>.<name>` sites keep working.

## Impact

- **Affected files** (creation only):
  - `modules/nix-lib/cross-class-modules.nix` (new, ~40 lines with
    doc comment).
  - `tests/scenarios/cross-class-modules/` (new, ~4 test files under
    the existing scenarios convention).
  - `README.md` (small section).
- **Not affected**: existing option modules; existing consumers do
  not need to change.
- **Downstream driver**: nix-oci change
  `declarative-cross-class-modules` consumes this after it lands.
  That change bumps `inputs.nix-lib` to the rev containing this
  primitive.
- **Extensibility**: the initial `includes` semantics is deliberately
  minimal (flat list, per-class filter by each included module's own
  `classes`). If downstream ever needs a richer graph (transitive
  includes, cycle detection, provider parametrization), that is a
  separate change - not scoped here.

## Constraints observed

- **Libs live in nix-lib**: satisfied by construction.
- **Discovery through import-tree**: the new file lives under
  `modules/nix-lib/`, discovered by `internal-dendritic-import-tree`.
  No new import lines anywhere.
- **Everything through config/options**: consumers write to
  `flake.crossClassModules.<name>`; the aggregator reads
  `config.flake.crossClassModules` and writes `config.flake.modules`.
  Zero function-call surface.
