# Tasks: `cross-class-modules-primitive`

Companion: proposal.md, design.md.

Task priorities use the beads scale: 0=critical, 2=medium, 4=backlog.
Complexity is a rough eval-effort estimate. All tasks target the
change branch `feat/cross-class-modules-primitive`.

## 1. Primitive

- [x] **1.1** Create `modules/nix-lib/cross-class-modules.nix`. Declare `options.flake.crossClassModules` (attrs-of submodule with `classes` / `module` / `includes`) and derive `config.flake.modules` per the shape in design.md D2. Top-of-file docstring explains the seam, references the design doc, and shows one symmetric + one asymmetric example. Verified: direct `lib.evalModules` smoke test on `foo` + `bar` + `composer` + `interop` inputs produces the expected `flake.modules.<class>` shapes. Priority: 0. Complexity: S.

- [x] **1.2** Confirm auto-discovery: the file lives under `modules/nix-lib/` and is picked up by the import-tree in `modules/nix-lib/_default.nix`. No additional wiring needed. Verified: `nix flake show` succeeds and the aggregate `checks.<system>.tests` derivation includes the new tests (see 2.5). Priority: 0. Complexity: XS.

## 2. Tests

- [x] **2.1-2.4** Consolidated into `tests/bdd/cross-class-modules.nix` following the existing BDD convention in `tests/bdd/libDef.nix` / `collectors.nix` (a single flake-parts module contributing `flake.tests.test_*` records, evaluated by the shared `check-runTests` / `check-nix-unit` backends in `modules/_dev/module.nix`). Full scenarios: (i) symmetric on three classes, (ii) asymmetric on nixos + systemManager with HM absent, (iii) composer with per-class `includes` filter (subA on both classes, subB nixos-only, composer HM cell must drop subB), (iv) interop fallback (hand-written `flake.modules.nixos.legacy` reachable through composer `includes`). 15 assertions total (4 + 3 + 6 + 2). Verified: `lib.debug.runTests` returns `{ total = 15; failed = 0; failures = []; }`. **Note**: dropped the per-scenario `tests/scenarios/cross-class-modules/*.nix` sub-flake layout described in the original plan; sub-flakes with `get-flake` are the scenario convention for backend-integration tests, not for module-primitive unit tests. Priority: 0. Complexity: M.

- [x] **2.5** Wired the BDD file into the dev partition at `modules/_dev/module.nix` alongside `libDef.nix` and `collectors.nix` (one-line import). The existing `check-runTests` / `check-nix-unit` backends aggregate `flake.tests` automatically; the new 15 tests join the `checks.<system>.tests` composite derivation without a dedicated new check. Priority: 0. Complexity: XS.

## 3. Docs

- [x] **3.1** Added "Cross-class module registration" section to `README.md` (inserted before the existing "Test Formats" heading). Includes one symmetric example, one asymmetric example, one composer example with per-class `includes` filter, and a link to the design doc at `openspec/changes/cross-class-modules-primitive/design.md`. Priority: 2. Complexity: XS.

## 4. Ship

- [ ] **4.1** Merge the branch. Note the merge-commit SHA and expose it to the nix-oci change owner. Verify with `gh api repos/Dauliac/nix-lib/commits/<sha>` returns 200 and the commit diff touches `modules/nix-lib/cross-class-modules.nix`. Priority: 0. Complexity: XS. Parallelism: after 2.5 + 3.1.

- [ ] **4.2** After the nix-oci change lands, revisit whether the interop fallback (D4) is still needed anywhere else. If no other consumer relies on it, open a follow-up to remove it. Priority: 4. Complexity: XS. Parallelism: after nix-oci change closes.
