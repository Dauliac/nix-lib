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

- [ ] **1.5** Pass `importTree` via `_module.args.importTree` in `modules/nix-lib-outputs.nix` so internal flake-parts modules can pick it up as a module argument (design D2, Q2). Optional: current uses go through direct `import ./_lib/import-tree` at each call site, which is fine. Priority: 2. Complexity: S. Parallelism: after 1.4.

## 2. Replace hand-maintained lists

- [x] **2.1** `modules/nix-lib/_all.nix` deleted. Its 7-file set is now produced by an `importTree.match` filter inside `mkAdapter.nix` (design D6), which is the only consumer left after 2.2 and 2.3. Priority: 0. Complexity: M. Parallelism: after 3.1.

- [x] **2.2** `modules/nix-lib/_default.nix` body replaced with `imports = [ (importTree ./.) ]`. Verified: `nix flake show` output surface unchanged, `nix build .#checks.x86_64-linux.tests` green. Priority: 0. Complexity: M. Parallelism: after 1.4.

- [x] **2.3** `modules/nix-lib/_pure.nix` body replaced with `importTree.filterNot` excluding `/docs/` and `/lib/perSystem.nix`. Legacy `/legacyPackages/` was NOT excluded because the current pure variant already includes it (verified against the pre-change `_pure.nix` explicit list). Priority: 0. Complexity: M. Parallelism: after 1.4.

- [x] **2.4** `modules/nix-lib/adapterDefs/default.nix` builtins list replaced with `importTree ./builtins`. All 7 builtin adapters still register (checked via `nix build .#checks`). Priority: 2. Complexity: S. Parallelism: after 1.4.

## 3. Decoupling

- [x] **3.1** `mkAdapter.nix` decoupled from `../_all.nix`. New signature: `mkAdapter { name, namespace ? null, adapterDef ? ..., extraImports ? [ ] }`. The default core-option set is now a regex-scoped `importTree.match` over `modules/nix-lib/`, matching the exact same 7 files the old `_all.nix` listed. `extraImports` lets advanced consumers layer additional option modules without forking. Priority: 0. Complexity: M. Parallelism: after 2.2.

- [x] **3.2** Grep-verified: no code path still references `_all.nix`. Only doc/openspec references remain. `git rm modules/nix-lib/_all.nix` shipped in the same commit as 2.1 / 3.1. Priority: 2. Complexity: S. Parallelism: after 3.1.

## 4. Dev-side discovery

- [ ] **4.1** Adopt `importTree` in `modules/_dev/module.nix` for `tests/scenarios/` and `examples/` (design D7). Reuse the vendored copy from `_lib/import-tree/`; do NOT add a partition-side `import-tree` input. Priority: 2. Complexity: M. Parallelism: after T04.

- [ ] **4.2** Add a dev-partition regression test: enumerating scenarios via `importTree` matches the current hand-wired set at the moment of the migration (guard against silent scope changes from filter mistakes). Priority: 2. Complexity: S. Parallelism: after T12.

## 5. Guardrails and docs

- [ ] **5.1** Add a nix-unit (or bats) check: every `.nix` file under `modules/nix-lib/` whose basename does not start with `_` and whose path does not contain `/_` must be reachable from at least one of `flakeModules.default` or `flakeModules.pure`. This prevents orphaned modules after list removal. Priority: 0. Complexity: M. Parallelism: after T08.

- [x] **5.2** Consumer-lock regression check landed as `modules/_dev/consumer-lock-shape.nix`. Adds `checks.consumer-lock-shape` at build time: asserts `flake.lock.root.inputs == [flake-parts, nixpkgs-lib]`, that the node count is exactly 3, and that a blacklist of dev-partition inputs (import-tree, nixpkgs, nix-unit, treefmt-nix, nixtest, nix-tests, nixt, namaka, devour-flake, get-flake, flake-file) never appears in the lock. Fails loudly via `throw` messages that name the regression. Simpler than a scratch consumer subflake and asserts the same invariant, since anything in nix-lib's own lock propagates to every consumer.

- [ ] **5.3** Update `CONTRIBUTING.md` to document: - The `_`-prefix convention for private files. - How to add a new option module (drop a file; no index edit). - How to add a new adapter builtin (drop a file under `adapterDefs/builtins/`). - How to refresh the vendored `import-tree`. Priority: 2. Complexity: S. Parallelism: after T14.

- [ ] **5.4** Update `README.md` "Architecture" section to mention that internal modules are auto-discovered but that this is an implementation detail; the public API is unchanged. Priority: 4. Complexity: XS. Parallelism: after T16.

- [ ] **5.5** Record the denful-ecosystem skip-list decisions from proposal.md ("Denful ecosystem alignment") in a short section of `CONTRIBUTING.md` (or a lightweight ADR under `openspec/`, whichever the project prefers), so future contributors see the rationale without reading the archived proposal. Cover: `flake-file`, `flake-aspects`, `den`, `dendrix`, `gen`, `dnx`. One line per tool. Priority: 4. Complexity: XS. Parallelism: after T14.

## 6. Cleanup

- [ ] **6.1** Once T06-T10 have shipped and stabilised, consider further compaction: are `_all.nix`, `_default.nix`, `_pure.nix` still three separate files, or can they merge into one entry-point with a `pure` toggle? Out-of-scope for this change; capture as a follow-up bead in `bd`. Priority: 4. Complexity: M. Parallelism: post-merge.

## Verification checklist (run before archive)

- [ ] `nix flake check` passes on `main` merge preview.
- [ ] All 15 flakes under `examples/` evaluate.
- [ ] BDD tests pass (`tests/bdd/`).
- [ ] All 5 scenario subflakes under `tests/scenarios/` evaluate.
- [ ] `nix flake metadata --json` on a scratch consumer flake shows
  exactly the pre-change transitive input set.
- [ ] `hunk diff --watch` review: net line delta is negative (list
  files shrink, no big new module).
- [ ] `docs` package build unchanged.
