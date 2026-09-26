# Tasks: `internal-dendritic-import-tree`

Companion: proposal.md, design.md.

Task priorities use the beads scale: 0=critical, 2=medium, 4=backlog.
Complexity is a rough eval-effort estimate. All tasks target the
change branch `feat/internal-dendritic-import-tree`.

## 1. Vendor and wire

- [ ] **1.1** Vendor `import-tree` upstream `default.nix` into `modules/nix-lib/_lib/import-tree/default.nix`. Preserve MIT LICENSE header verbatim inside the file. Add a top comment with upstream commit hash and refresh instructions (see design D1). Priority: 0. Complexity: XS. Parallelism: sequential-blocker.

- [ ] **1.2** Copy upstream `tests.nix` (executable spec) into `modules/nix-lib/_lib/import-tree/tests.nix`. Attribute in the same header block. Priority: 2. Complexity: XS. Parallelism: after T01.

- [ ] **1.3** Add a top-level NOTICE (or a section in README under "Third-party components") crediting `denful/import-tree` (MIT). Priority: 2. Complexity: XS. Parallelism: after T01.

- [ ] **1.4** Expose the vendored function inside `modules/nix-lib/_lib/default.nix` as `importTree`. Do NOT merge into `lib.*` in `flake.nix`. Priority: 0. Complexity: S. Parallelism: after T01.

- [ ] **1.5** Pass `importTree` via `_module.args.importTree` in `modules/nix-lib-outputs.nix` (or a dedicated `modules/_args.nix`) so every internal flake-parts module can pick it up as a module argument (design D2, Q2). Priority: 2. Complexity: S. Parallelism: after T04.

## 2. Replace hand-maintained lists

- [ ] **2.1** Replace `modules/nix-lib/_all.nix` body with an `importTree` call scoped to the core-option subset (design D5, D6). Add a test asserting the resulting `imports` set is equal to the previous hand list (fixture-based regression). Then commit. Priority: 0. Complexity: M. Parallelism: after T04.

- [ ] **2.2** Replace `modules/nix-lib/_default.nix` body with an `importTree` call over the full `modules/nix-lib/` tree. Verify by running the existing BDD suite + all 15 `examples/` still evaluate. Priority: 0. Complexity: M. Parallelism: after T06.

- [ ] **2.3** Replace `modules/nix-lib/_pure.nix` body with an `importTree.filterNot` call excluding `/docs/`, `/legacyPackages/`, and `/lib/perSystem.nix` (design D5). Add a nix-unit test asserting the pure module never touches `pkgs`-dependent paths. Priority: 0. Complexity: M. Parallelism: after T06.

- [ ] **2.4** Replace the hand-maintained `imports` in `modules/nix-lib/adapterDefs/default.nix` with `importTree ./builtins`. Verify all 7 builtin adapters (nixos, home-manager, nix-darwin, nixvim, system-manager, wrappers, perSystem) still register. Priority: 2. Complexity: S. Parallelism: after T04.

## 3. Decoupling

- [ ] **3.1** Decouple `modules/nix-lib/_lib/mkAdapter.nix:237` from `../_all.nix`. Introduce an `imports` (or `extraImports`) argument with default equal to the `importTree`-based core-option list (design D6). Preserve public signature: `mkAdapter { name = "..."; }` still works identically. Priority: 0. Complexity: M. Parallelism: after T06.

- [ ] **3.2** Verify no other file hardcodes internal paths. Grep `modules/` for relative imports of `_all.nix`, `_default.nix`, `_pure.nix`, or `adapterDefs/default.nix`. Any hit is either legitimate (the entry-point modules themselves) or a leak. Priority: 2. Complexity: S. Parallelism: after T10.

## 4. Dev-side discovery

- [ ] **4.1** Adopt `importTree` in `modules/_dev/module.nix` for `tests/scenarios/` and `examples/` (design D7). Reuse the vendored copy from `_lib/import-tree/`; do NOT add a partition-side `import-tree` input. Priority: 2. Complexity: M. Parallelism: after T04.

- [ ] **4.2** Add a dev-partition regression test: enumerating scenarios via `importTree` matches the current hand-wired set at the moment of the migration (guard against silent scope changes from filter mistakes). Priority: 2. Complexity: S. Parallelism: after T12.

## 5. Guardrails and docs

- [ ] **5.1** Add a nix-unit (or bats) check: every `.nix` file under `modules/nix-lib/` whose basename does not start with `_` and whose path does not contain `/_` must be reachable from at least one of `flakeModules.default` or `flakeModules.pure`. This prevents orphaned modules after list removal. Priority: 0. Complexity: M. Parallelism: after T08.

- [ ] **5.2** Add a consumer-lock regression test: build a scratch consumer flake in `tests/scenarios/consumer-lock-shape/` that imports `nix-lib.flakeModules.default` and asserts `nix flake metadata --json | jq '.locks.nodes | keys'` contains exactly `["flake-parts", "nixpkgs-lib", "root"]` (or the current baseline). Locks import-tree out. Priority: 0. Complexity: M. Parallelism: after T08.

- [ ] **5.3** Update `CONTRIBUTING.md` to document: - The `_`-prefix convention for private files. - How to add a new option module (drop a file; no index edit). - How to add a new adapter builtin (drop a file under `adapterDefs/builtins/`). - How to refresh the vendored `import-tree`. Priority: 2. Complexity: S. Parallelism: after T14.

- [ ] **5.4** Update `README.md` "Architecture" section to mention that internal modules are auto-discovered but that this is an implementation detail; the public API is unchanged. Priority: 4. Complexity: XS. Parallelism: after T16.

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
