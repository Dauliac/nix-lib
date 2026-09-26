# Proposal: adopt `import-tree` internally without exposing it to consumers

Change ID: `internal-dendritic-import-tree`
Status: draft
Date: 2026-09-26
Companion research: `openspec/research/{import-tree.md, flake-parts-partitions.md, nix-oci-audit.md, nix-lib-current.md}`

## Summary

Refactor nix-lib's internal module organization to use the `import-tree`
dendritic pattern (already adopted successfully in nix-oci), while
keeping `import-tree` invisible to downstream consumers. Achieve this
by **vendoring** the single-file MIT-licensed `import-tree` into
`modules/nix-lib/_lib/import-tree/` and calling it only from internal
modules.

## Why

Three current pain points motivate this:

1. **Hand-maintained import lists**. `modules/nix-lib/_default.nix` (12
   imports), `modules/nix-lib/_pure.nix` (10 imports), and
   `modules/nix-lib/_all.nix` (7 imports) are three parallel lists that
   drift when someone adds a new option module. `modules/nix-lib/adapterDefs/default.nix`
   is a fourth. See `research/nix-lib-current.md` section 6.
2. **Coupling**. `modules/nix-lib/_lib/mkAdapter.nix:237` hardcodes
   `imports = [ ../_all.nix ]`, meaning the factory can never be moved
   or reused apart from that list.
3. **Manual dev-side wiring**. `tests/scenarios/` growth forces manual
   updates to the dev partition. Same for future `examples/`.

The dendritic pattern (see `research/import-tree.md` section on
mightyiam/dendritic) solves all three by treating every file under a
directory as a top-level module, discovered by walking the tree at
eval time.

## Constraint: import-tree must not leak to consumers

Two anti-goals:

- **No new consumer input.** A downstream flake that says
  `inputs.nix-lib.url = ...` today gets exactly `flake-parts` and
  `nixpkgs-lib` transitively (see `research/nix-lib-current.md`
  section 4). After this change, they must still get exactly those two.
- **No consumer-time dependency on `import-tree` at their eval.** The
  paths that `import-tree` discovers must resolve inside nix-lib's own
  store path, not the consumer's.

The two mechanisms available in the research answer this cleanly:

- Partitions hide inputs from the consumer's lock file
  (`research/flake-parts-partitions.md`: `extraInputsFlake` uses
  vendored flake-compat and is not registered as an input). **But**
  `lib.*` outputs must not be partitioned, because consumer eval of
  `lib.mkFlake` would trigger partition eval. This rules out putting
  `import-tree` into a partition-side input for the parts of nix-lib
  that shape `flakeModules.default`, `flakeModules.pure`, or
  `<system>Modules.default`.
- **Vendoring** import-tree (MIT, single 268-line file, zero inputs,
  uses only `builtins.*`) sidesteps both concerns. The tree walk runs
  against nix-lib's own store path; no consumer-visible input is
  introduced (`research/import-tree.md` section on runtime input
  behaviour).

Verdict: vendor. Optional secondary use in the dev partition is a bonus
but not required.

## What changes

1. Vendor `import-tree/default.nix` (MIT) as
   `modules/nix-lib/_lib/import-tree/default.nix`, keeping LICENSE
   attribution intact.
2. Wire the vendored copy through `modules/nix-lib/_lib/default.nix`
   as `_lib.importTree` (internal only, not re-exported from `lib.*`).
3. Replace the three hand-maintained lists (`_all.nix`, `_default.nix`,
   `_pure.nix`) with `importTree` calls that discover option modules by
   filename convention.
4. Replace `modules/nix-lib/adapterDefs/default.nix` builtin list with
   a scoped `importTree ./builtins`.
5. Break the `mkAdapter.nix:237` coupling: mkAdapter should take an
   `imports` argument (with sensible default) rather than hard-referencing
   `../_all.nix`.
6. Use `importTree` in the dev partition (`modules/_dev/module.nix`)
   for test-scenario and example discovery, so adding a scenario or
   example under `tests/scenarios/` or `examples/` no longer requires
   editing the partition.
7. Adopt a `/_` prefix convention for internal-only files that
   `import-tree` should skip (matches the import-tree default filter).
   Rename existing `_lib`, `_all.nix`, `_default.nix`, `_pure.nix`,
   `_dev`, `_types`, `_factory.nix`, `_markdown.nix` to stay consistent
   (they already follow the convention).

## What stays exactly the same

- `flake.nix` inputs remain `flake-parts` and `nixpkgs-lib`.
- Public `lib.*` surface: `mkFlake`, `mkAdapter`, `evalLibModules`,
  `mkLib`, `mkSpecialArgsLib`, `withLib`.
- `flakeModules.default`, `flakeModules.pure`, `<system>Modules.default`
  entry points and their contracts.
- `nix-lib.lib.<name>` option shape.
- All 15 example flakes under `examples/` continue to work with zero
  changes.

## What might change subtly

- Order of `imports = [ ... ]` becomes filesystem-order, not
  author-chosen. This is Nix module-system merge, which is
  order-independent by design, but any code path that (wrongly) relied
  on ordering would break.
- File additions become effective without editing an index.
  Contributors need to know the convention (`_` prefix for private).

## Non-goals

- Do **not** add `import-tree` as a nix-lib flake input.
- Do **not** re-export `importTree` under `lib.*`. Keep it strictly
  internal.
- Do **not** move to the mightyiam/dendritic *layout* (which has its
  own conventions and its own module organizer). nix-lib keeps its
  current directory shape; only the discovery mechanism changes.
- Do **not** refactor `flake-parts` partitions setup. Existing dev
  partition stays as it is (see `modules/partitions.nix`).

## Risks

1. **License compliance for vendored code.** import-tree is MIT.
   Preserving the LICENSE header at the top of the vendored file and
   listing the upstream in a NOTICE (or the README) is required.
2. **Silent upstream divergence.** Because we vendor rather than pin,
   we won't get upstream bug fixes automatically. Mitigation: add a
   comment at the top of the vendored file with the upstream commit
   hash and a note on how to refresh.
3. **File-naming regressions.** Any file dropped into a discovered
   directory becomes a live module. Mitigation: strict `_`-prefix
   convention for internal helpers, and CI check (see tasks).
4. **Filter mistakes hiding modules.** A mistyped filter could silently
   exclude an option module. Mitigation: a test that asserts every
   `.nix` file in `modules/nix-lib/` (excluding `_`-prefixed) is
   reachable via at least one of the entry-point module chains.

## Success criteria

- After the change, `nix flake metadata` on a consumer flake reports
  the same transitive inputs as before (verified against a scratch
  consumer flake).
- Adding a new option module under `modules/nix-lib/` requires editing
  zero index files.
- `mkAdapter` no longer references `../_all.nix` by path.
- All existing tests and BDD scenarios pass unchanged.
- The 15 `examples/` still evaluate.

## Out of scope (follow-ups worth their own change)

- Migrating fully to the dendritic layout convention (mightyiam-style).
- Splitting off a separate `flakeModules.minimal` variant.
- Adding a `lib.importTree` public helper (would violate the anti-goal
  above; would need its own proposal).
