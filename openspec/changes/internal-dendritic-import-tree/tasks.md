# Tasks: `internal-dendritic-import-tree`

Companion: proposal.md, design.md.

Task priorities use the beads scale: 0=critical, 2=medium, 4=backlog.
Complexity is a rough eval-effort estimate. All tasks target the
change branch `feat/internal-dendritic-import-tree`.

## 1. Vendor and wire

- [x] **1.1** Vendor `import-tree` upstream `default.nix` into `modules/nix-lib/_lib/import-tree/default.nix`. Full Apache 2.0 LICENSE at sibling `LICENSE` file. Header carries pinned commit and refresh instructions. Priority: 0. Complexity: XS. Parallelism: sequential-blocker.

- [x] **1.2** Copy upstream `tests.nix` into `modules/nix-lib/_lib/import-tree/tests.nix` for regression fixture on refresh. Priority: 2. Complexity: XS. Parallelism: after 1.1.

- [x] **1.3** README "Third-party components" section credits `denful/import-tree` (Apache 2.0) and points at the vendored LICENSE. Priority: 2. Complexity: XS. Parallelism: after 1.1.

- [x] **1.4** `modules/nix-lib/_lib/default.nix` exposes `importTree`. NOT re-exported into `lib.*` (verified: `flake.nix` still `inherit`s an explicit name list that does not include `importTree`). Priority: 0. Complexity: S. Parallelism: after 1.1.

- [ ] **1.5** Pass `importTree` via `_module.args.importTree`. Deferred: current usage patterns (`import ./_lib/import-tree` from within `_default.nix`, `_pure.nix`, `mkAdapter.nix`, `adapterDefs/default.nix`) are all single-line and self-contained. `_module.args` wiring would only pay off if a fifth or sixth call site appears. Priority: 4.

## 2. Replace hand-maintained lists

- [x] **2.1** `modules/nix-lib/_all.nix` deleted. Its 7-file set is now produced by an `importTree.match` filter inside `mkAdapter.nix` (design D6), which is the only consumer left after 2.2 and 2.3. Priority: 0. Complexity: M. Parallelism: after 3.1.

- [x] **2.2** `modules/nix-lib/_default.nix` body replaced with `imports = [ (importTree ./.) ]`. Verified: `nix flake show` output surface unchanged, `nix build .#checks.x86_64-linux.tests` green. Priority: 0. Complexity: M. Parallelism: after 1.4.

- [x] **2.3** `modules/nix-lib/_pure.nix` body replaced with `importTree.filterNot` excluding `/docs/` and `/lib/perSystem.nix`. Legacy `/legacyPackages/` was NOT excluded because the current pure variant already includes it (verified against the pre-change `_pure.nix` explicit list). Priority: 0. Complexity: M. Parallelism: after 1.4.

- [x] **2.4** `modules/nix-lib/adapterDefs/default.nix` builtins list replaced with `importTree ./builtins`. All 7 builtin adapters still register (checked via `nix build .#checks`). Priority: 2. Complexity: S. Parallelism: after 1.4.

## 3. Decoupling

- [x] **3.1** `mkAdapter.nix` decoupled from `../_all.nix`. New signature: `mkAdapter { name, namespace ? null, adapterDef ? ..., extraImports ? [ ] }`. The default core-option set is now a regex-scoped `importTree.match` over `modules/nix-lib/`, matching the exact same 7 files the old `_all.nix` listed. `extraImports` lets advanced consumers layer additional option modules without forking. Priority: 0. Complexity: M. Parallelism: after 2.2.

- [x] **3.2** Grep-verified: no code path still references `_all.nix`. Only doc/openspec references remain. `git rm modules/nix-lib/_all.nix` shipped in the same commit as 2.1 / 3.1. Priority: 2. Complexity: S. Parallelism: after 3.1.

## 4. Dev-side discovery

- [ ] **4.1** Adopt `importTree` in `modules/_dev/module.nix` for `tests/scenarios/` and `examples/`. Deferred: `tests/scenarios/*` are subflakes (with their own `flake.nix`), not flake-parts modules, so `importTree` in its default mode would not directly help. Would need a custom pipeline (walk to find `flake.nix` files, invoke `get-flake` per subflake). Not blocking the main OpenSpec change. Left as a follow-up bead. Priority: 4.

- [ ] **4.2** Same status: waits on 4.1. Priority: 4.

## 5. Guardrails and docs

- [x] **5.1** Reachability guarantee is now **by construction**: `flakeModules.default` = `importTree ./.` picks up every non-`_` `.nix` file under `modules/nix-lib/` automatically, and `flakeModules.pure` = the same walk minus `/docs/` and `/lib/perSystem.nix`. An additional check would only re-assert the fixpoint of the discovery algorithm. Left as a documented invariant in `CONTRIBUTING.md` under "File-naming convention (internal auto-discovery)". Priority downgraded to 4; not shipping a redundant check.

- [x] **5.2** Consumer-lock regression check landed as `modules/_dev/consumer-lock-shape.nix`. Adds `checks.consumer-lock-shape` at build time: asserts `flake.lock.root.inputs == [flake-parts, nixpkgs-lib]`, that the node count is exactly 3, and that a blacklist of dev-partition inputs (import-tree, nixpkgs, nix-unit, treefmt-nix, nixtest, nix-tests, nixt, namaka, devour-flake, get-flake, flake-file) never appears in the lock. Fails loudly via `throw` messages that name the regression. Simpler than a scratch consumer subflake and asserts the same invariant, since anything in nix-lib's own lock propagates to every consumer.

- [x] **5.3** `CONTRIBUTING.md` rewritten "Project Structure" section documents the `_`-prefix convention, how to add a new option module, how to add a new adapter builtin, and the refresh flow for the vendored `import-tree`. Landed in the mkAdapter decouple commit (67a7859).

- [x] **5.4** `README.md` "Third-party components" section calls out the vendored copy with license and refresh pointer. The main "Lib Modules Architecture" diagram intentionally does NOT mention auto-discovery: the discovery mechanism is an internal implementation detail and the diagram documents public-consumer flow.

- [x] **5.5** Denful ecosystem skip-list added to `CONTRIBUTING.md` under "Denful ecosystem skip-list" (one line per tool: `flake-file`, `flake-aspects`, `den`, `den-diagram`, `checkmate`, `dendrix`, `gen`, `dnx`), each linking out to its `openspec/research/denful-*.md` audit where one exists. Contributors see the "why not" without archaeology.

- [x] **5.6** "Downstream quick-check (no clone needed)" section added to `README.md`. Documents the external `checkmate` invocation as a downstream convenience with the exact command line, plus a callout that this is NOT a nix-lib dependency: the same two backends it wraps (`nix-unit`, `treefmt`) are already among the seven our dev partition runs. Links to `openspec/research/denful-checkmate.md`.

## 6. Cleanup

- [ ] **6.1** Once T06-T10 have shipped and stabilised, consider further compaction: are `_all.nix`, `_default.nix`, `_pure.nix` still three separate files, or can they merge into one entry-point with a `pure` toggle? Out-of-scope for this change; capture as a follow-up bead in `bd`. Priority: 4. Complexity: M. Parallelism: post-merge.

## Verification checklist (run before archive)

- [x] `nix build .#checks.x86_64-linux.tests --no-link` passes on
  the feat branch (13-14s cached green through all three commits).
- [x] `nix build .#checks.x86_64-linux.consumer-lock-shape` passes,
  proving the anti-goal is machine-enforced.
- [x] BDD test files under `tests/bdd/` still discovered by the dev
  partition (libDef.nix, collectors.nix).
- [x] All existing scenario subflakes under `tests/scenarios/` still
  present and referenced; not touched by this change.
- [x] Consumer-lock invariant asserted in-tree via
  `modules/_dev/consumer-lock-shape.nix`: root inputs stay
  `[flake-parts, nixpkgs-lib]`; flake.lock node count is 3.
- [ ] `hunk diff --watch` review by human: net delta on the
  refactor is `-46` lines in the list files, `+3785` for vendored
  code + docs + research. Suggest reviewing per commit
  (`git log --reverse -p`) rather than as one blob.
- [x] `docs` package build unchanged: `nix-lib-docs` derivation
  still resolves via `checks.tests -> check-docs -> nix-lib-docs`
  and produces the same rendered markdown structure.
