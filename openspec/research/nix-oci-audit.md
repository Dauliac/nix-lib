# nix-oci Dendritic Pattern Audit

## 1. Directory Tree (nix/, dev/, docs/  -  Nix files only, 4 levels max)

```
nix/
├── module.nix                     (top-level flake module glue)
├── flake-module.nix               (public flake-parts module)
├── test-flake-module.nix          (test infrastructure)
├── examples.nix                   (auto-discover examples via import-tree)
├── templates.nix                  (template exports)
├── treefmt.nix                    (formatter config)
├── docs.nix                       (docs build module)
├── lib/                           (library functions, not auto-discovered)
│   ├── eval-container.nix
│   ├── oci.nix
│   └── ... (10+ helper modules)
└── modules/                       (auto-discovered via import-tree)
    ├── deploy/                    (deployed to flake.modules.nixos/homeManager/systemManager)
    │   └── nix-oci/
    │       ├── compose.nix
    │       ├── nixos/
    │       ├── home-manager/
    │       ├── system-manager/
    │       └── options/
    ├── oci/                       (core OCI flake-parts namespace)
    │   ├── namespace.nix
    │   ├── paths.nix
    │   ├── turbo.nix
    │   ├── containers/            (container options, 4 levels deep)
    │   ├── outputs/               (app/package/check wiring)
    │   ├── pipeline/              (gate checks composition)
    │   ├── security/              (CVE, SBOM, signing, lint)
    │   ├── testing/               (probe tools, VM checks)
    │   ├── lib/                   (40+ pure helper modules, no _prefix)
    │   └── _oci/                  (internal, underscore-prefixed)
    ├── flake/                     (flake-level outputs bridge)
    │   └── apps.nix, checks.nix, packages.nix, etc.
    ├── _nixos-oci/                (NixOS container eval, underscore-prefixed)
    │   ├── base.nix
    │   ├── environment/
    │   ├── gpu/
    │   └── ... (10+ sub-namespaces)
    ├── _home-manager-oci/         (HM container eval, underscore-prefixed)
    └── soci-snapshotter/          (snapshotting backend)

dev/flake.nix                      (dev-only inputs: treefmt-nix, home-manager, nix-vm-test, system-manager)
docs/flake.nix                     (docs-only inputs: github-actions-nix)
```

## 2. import-tree Call Sites (all usages with file:line and expressions)

### Main flake.nix (lines 15-42, 79)
- **Line 15-17**: Input declaration
  ```nix
  import-tree = {
    url = "github:denful/import-tree";
  };
  ```
- **Line 42**: Expose as `_module.args` for submodules
  ```nix
  _module.args.import-tree = inputs.import-tree;
  ```
- **Line 79**: Auto-discovery comment (examples imported via import-tree in nix/examples.nix)

### nix/module.nix (line 10)
- **Import deploy modules at top-level**  -  not partitioned (nixosModules/homeManagerModules live here)
  ```nix
  imports = [
    (inputs.import-tree ./modules/deploy)
  ];
  ```
  This call is DIRECT (no filters). Returns all Nix files under `./modules/deploy` as module imports.

### nix/flake-module.nix (line 16)
- **Auto-discover all OCI library modules** (core oci.* namespace)
  ```nix
  (inputs.import-tree ./modules)
  ```
  Also DIRECT. Imports everything under `./modules/` (oci/, flake/, _nixos-oci/, _home-manager-oci/, soci-snapshotter/). 
  The `_` prefix filters are implicit in module naming: directories prefixed with `_` are discovered but treated as namespace partitions (not auto-exposed).

### nix/test-flake-module.nix (line 11)
- **Auto-discover testing infrastructure**
  ```nix
  imports = [
    (inputs.import-tree ./modules/oci/testing)
  ];
  ```
  DIRECT. Scoped to `./modules/oci/testing/` only.

### nix/examples.nix (line 28)
- **Filtered import with `.filterNot()`**  -  excludes large/slow examples
  ```nix
  exampleTree = inputs.import-tree.filterNot (
    path: lib.any (pattern: lib.hasInfix pattern path) excludes
  );
  ...
  imports = [ (exampleTree ../examples/flake) ];
  ```
  Uses `.filterNot()` method chained on `inputs.import-tree`. The `excludes` list filters by path pattern:
  - `/base-images/` (slow, large)
  - `/multi-arch/` (multi-target builds)
  - `/with-home-manager-` (special case)
  - `/minimalist-with-*` (specific tool bundles)

### nix/docs.nix (lines 27, 118-119, 196)
- **Line 27**: Expose import-tree in perSystem scope
  ```nix
  import-tree = inputs.import-tree;
  ```
- **Lines 118-119**: Resolve option trees for docs (no filters)
  ```nix
  sharedOptions = import-tree ./modules/oci/containers/_options;
  deployExtensions = import-tree ./modules/deploy/nix-oci/options/_containers;
  ```
- **Line 196**: Discover NixOS container eval modules for docs
  ```nix
  ociNixOSModule = import-tree ./modules/_nixos-oci;
  ```

**Pattern**: import-tree is ONLY called in three ways:
1. **Direct**: `inputs.import-tree ./path`  -  imports all Nix files recursively
2. **Filtered**: `inputs.import-tree.filterNot(pred)`  -  excludes paths matching predicate
3. **Called in submodules**: Re-exposed via `_module.args.import-tree` for nested usage

No `.addAPI`, `.pipe`, or other transformations observed. No module-level deferred evaluation.

## 3. Partition Wiring (root flake.nix lines 44-142)

### partitionedAttrs (lines 45-53)
```nix
partitionedAttrs.apps = "dev";
partitionedAttrs.packages = "dev";
partitionedAttrs.checks = "dev";
partitionedAttrs.devShells = "dev";
partitionedAttrs.formatter = "dev";
partitionedAttrs.tests = "dev";

partitionedAttrs.legacyPackages = "docs";
```

### Partition Config: docs (lines 55-67)
```nix
partitions.docs = {
  extraInputsFlake = ./docs;
  module = { inputs, ... }: {
    imports = [
      inputs.github-actions-nix.flakeModules.default
      ./nix/docs.nix
      (import ./nix/flake-module.nix inputs)
    ];
    oci.enabled = true;
  };
};
```

### Partition Config: dev (lines 69-142)
```nix
partitions.dev = {
  extraInputsFlake = ./dev;
  module = { inputs, ... }: {
    imports = [
      (import ./nix/flake-module.nix inputs)       # Full OCI lib
      (import ./nix/test-flake-module.nix inputs)  # BDD infra
      (import ./nix/examples.nix { })              # Example containers
      ./nix/treefmt.nix                            # Formatter
    ];
    oci.enabled = true;
    oci.enableFlakeOutputs = false;                # Suppress auto-emit
    oci.flake.exposeUnitTests = true;              # Expose flake.tests
    debug = true;
    perSystem = { config, pkgs, lib, ... }: {
      oci.turbo.enable = true;
      oci.fromImageManifestRootPath = ./oci + "/";
      checks = {
        bdd-vm = config.test.oci._bddVmCheck;      # Auto-aggregated
        bdd-apps = config.test.oci._bddAppsCheck;
      };
      devShells.default = pkgs.mkShell { ... };    # Dev tools
    };
  };
};
```

### Explanation
- **Root output** (no partition): Receives only `flake.modules.*` and `flake.templates`. Consumers see `nix flake show` with no packages/apps/checks at root  -  clean interface.
- **dev partition**: Contains all dev-facing outputs (apps, packages, checks, devShells, formatter, tests). Flake consumers never see this.
- **docs partition**: Isolated from consumers. Provides `legacyPackages` (mdbook site) only. Has separate inputs (github-actions-nix). Exports flake.tests hidden (nix-lib auto-emit).
- **Per-system wiring**: Manual checks (BDD VM + apps) aggregated in dev's perSystem. Turbo push enabled only in dev. Lock files scoped to `./oci/`.

## 4. Module Organization Patterns

### _lib vs Public Split
- **Private utility functions**: `nix/lib/*.nix` (not auto-discovered, hand-imported only)
  - `eval-container.nix`  -  evaluate per-container config
  - `oci.nix`  -  pure lib, exported to `config.oci.internal.lib`
  - `discoverModules.nix`  -  walk directories, return module list (used by compose.nix)
  - These are NOT prefixed with `_` because they live outside `modules/`.

- **Public namespaced modules**: `nix/modules/oci/lib/*.nix` (40+ files, no underscore prefix)
  - `mkOCIImage.nix`, `mkPushApp.nix`, `mkHardenedConfigs.nix` etc.
  - Auto-discovered via `import-tree ./modules` but namespace-partitioned (not imported as flake-parts modules)
  - These contribute to the `config.oci.lib.*` namespace (available to downstream consumers in their module context)

- **Internal underscore-prefixed partitions**: `nix/modules/_nixos-oci/`, `nix/modules/_home-manager-oci/`, `nix/modules/_oci/`, `nix/modules/oci/_testing/`, `nix/modules/oci/testing/_python-gen.nix`
  - Discovered but NOT auto-imported as flake-parts modules (import-tree skips `_`-prefixed dirs by convention)
  - Manually imported where needed (e.g., `discoverModules ../../../_nixos-oci` in compose.nix, or `ociNixOSModule = import-tree ./modules/_nixos-oci` in docs.nix)

### Naming Conventions
1. **Files prefixed with `_`**: Not auto-imported by import-tree (e.g., `_mkProbeToolBundle.nix`, `_option-test-spec.nix`, `_python-gen.nix`)
   - Used for helper functions, internal specs, implementation details
   - Imported only where explicitly needed

2. **Directories prefixed with `_`**: Same rule
   - `_nixos-oci`  -  NixOS container baseline + namespace
   - `_home-manager-oci`  -  HM container baseline
   - `_oci`  -  Internal gate check logic, CVE scanning implementation
   - `_testing`  -  VM check builder, probe tool bundles
   - These ARE discovered but must be explicitly imported (not auto-wired)

3. **Public modules**: No prefix
   - `containers/`, `outputs/`, `lib/`, `pipeline/`, `security/`, `testing/`, `soci-snapshotter/`
   - Auto-discovered and auto-imported as flake-parts modules (or scoped to oci.* namespace)

### Examples (3-4 concrete patterns):

**Example 1: Container options** (`nix/modules/oci/containers/`)
- Auto-discovered. Contributes to flake-parts module hierarchy.
- Submodule: `nixosConfig/`  -  deferred evaluation, called with ociLib + inputs
- Submodule: `_options/`  -  underscore prefix, not auto-imported (manually merged in docs.nix)
- Pattern: Public container builders with private option partitions

**Example 2: Testing infrastructure** (`nix/modules/oci/testing/`)
- Auto-discovered by `import-tree ./modules/oci/testing` (nix/test-flake-module.nix:11)
- Submodule: `test-collector.nix`  -  main BDD aggregator
- Submodule: `_python-gen.nix`  -  internal, underscore prefix (called by test-collector.nix, not auto-imported)
- Pattern: Public entry point with internal implementation

**Example 3: Security checks** (`nix/modules/oci/security/` and `nix/modules/oci/_oci/`)
- `security/` auto-discovered, contains CVE/SBOM/signing gates
- `_oci/` underscore-prefixed (internal), but import-tree still discovers it
- Pattern: Public gates (security/*) reference internal specs (_oci/*)

**Example 4: Deploy modules** (`nix/modules/deploy/nix-oci/`)
- Auto-discovered by `import-tree ./modules/deploy` (nix/module.nix:10)
- Submodule: `compose.nix`  -  manually constructs `flake.modules.nixos.nix-oci`, `flake.modules.homeManager.nix-oci`
- Submodule: `options/`  -  option declarations for deploy-time config
- Pattern: Public partition with internal option bridge

## 5. The `_module.args.import-tree = inputs.import-tree;` Idiom

**Primary exposure** (nix/flake.nix:42):
```nix
_module.args.import-tree = inputs.import-tree;
```

This makes `import-tree` available to all imported modules as an argument. Used by:
- `nix/examples.nix` (line 28): `exampleTree = inputs.import-tree.filterNot(...)`
- `nix/docs.nix` (line 27): `import-tree = inputs.import-tree;` (re-exposed in perSystem scope)

**Pattern**: Single "golden" injection at root flake. All submodules access via function parameter or via re-export.

**Not re-exported from lib**: `import-tree` is a tool input (like `flake-parts`, `nix2container`), not a library function. nix-lib does NOT export it.

## 6. Consumer-Visible Surface (flake outputs)

A consumer running `nix flake show` on nix-oci would see:

```
outputs
├── modules
│   ├── flake
│   │   ├── nix-oci (the main module)
│   │   └── nix-oci-test (test module)
│   ├── nixos
│   │   ├── nix-oci (deploy module)
│   │   └── ... (auto-discovered from deploy/nix-oci/nixos/)
│   ├── homeManager
│   │   ├── nix-oci (deploy module)
│   │   └── ... (auto-discovered from deploy/nix-oci/home-manager/)
│   ├── systemManager
│   │   └── nix-oci (deploy module)
│   └── nixos-oci (the _nixos-oci eval module, exported by compose.nix)
├── templates
│   └── default (minimal flake template)
```

**Notably absent**: packages, apps, checks, devShells, formatter, tests  -  all hidden in dev partition.

**Why this is clean**:
- Consumer imports `nix-oci.modules.flake.nix-oci` into their flake and gets the OCI library.
- All dev/CI infra (examples, BDD checks, formatter) stays local to nix-oci's dev partition.
- Templates show by default (discoverable for new projects).

## 7. Adaptation Risks for nix-lib

### Compatibility Concerns

1. **nix-lib is pure-lib, nix-oci has pkgs-dependent outputs**
   - nix-oci: `nix2container`, `skopeo`, container images are pkgs-dependent
   - nix-lib: Only exports `lib.*` (pure functions, option defs, type defs)
   - **Risk**: nix-lib's partitions cannot suppress packages/apps/checks at root because nix-lib has no such outputs to hide. Adopting the same pattern but ONLY for `lib` re-exports and docs makes sense.

2. **Partition isolation vs dependency clarity**
   - nix-oci uses `extraInputsFlake` for dev/docs inputs (treefmt-nix, github-actions-nix)
   - nix-lib should do the same for dev-only inputs (e.g., mdbook, plutonium)
   - **Risk**: Ensure dev partition inputs aren't leaked to consumers (flake.lock should NOT include them). Mitigate: Use flake follow mechanism strictly.

3. **Module exposure via flake.modules**
   - nix-oci exports `flake.modules.nixos.nix-oci`, `flake.modules.homeManager.nix-oci`, `flake.modules.nixos-oci`
   - nix-lib should export `flake.modules.nixos.nix-lib`, `flake.modules.homeManager.nix-lib` (if HM support exists)
   - **Risk**: Currently nix-lib may NOT structure modules this way. Alignment needed.

4. **Filter patterns for examples**
   - nix-oci excludes slow/large examples via `.filterNot(path: ...)` in nix/examples.nix
   - nix-lib has NO examples directory yet; if added, same pattern applies
   - **Risk**: Low  -  just document the naming convention (underscore-prefix for internal, no exclusions needed initially).

### Safe Adoptions

1. **Partition wiring structure**  -  DIRECTLY adoptable
   - `partitionedAttrs.* = "dev"` for outputs
   - `partitions.dev` and `partitions.docs` scopes
   - `_module.args.import-tree` injection

2. **Directory naming**  -  DIRECTLY adoptable
   - Use `_` prefix for internal modules
   - Keep `lib/` outside `modules/` for non-auto-discovered utilities
   - Use `modules/` for all auto-discoverable (import-tree) modules

3. **Module composition**  -  PATTERN ADOPTABLE (with tweaks)
   - nix-oci: imports via `import ./nix/flake-module.nix inputs` (returns a module function)
   - nix-lib should do: `imports = [ inputs.flake-parts.flakeModules.modules inputs.flake-parts.flakeModules.partitions ./nix/module.nix ];`
   - Then in nix/module.nix, hand-curate the import-tree calls

### Known Limitations

- **import-tree doesn't support `.addAPI` or `.pipe`** in nix-oci. If nix-lib needs advanced module composition (e.g., lazy evaluation of large option sets), may need bespoke logic in flake.nix instead of relying on auto-discovery.
- **Underscore-prefixed dirs are discovered but not auto-imported**  -  if nix-lib needs to auto-import ALL modules (including internal), explicit `import-tree ./modules/_internal` call needed (breaking the underscore convention).

## Summary

nix-oci's dendritic pattern is **highly applicable** to nix-lib:
- **Good fit**: Partition separation (dev isolation), partition inputs (docs-only inputs), module discovery (import-tree), clean flake output surface.
- **Adaptation**: Use same partition structure but skip app/package/check hiding (nix-lib has no such outputs). Expose all `lib.*` at root (no partitioning of library functions).
- **Key files to replicate**: `flake.nix` partition wiring, `nix/module.nix` (import-tree ./modules/deploy pattern), `nix/flake-module.nix` (import-tree ./modules pattern), `dev/flake.nix` and `docs/flake.nix` (minimal inputs files).
- **Naming conventions**: Use `_` prefix for internal modules, no `lib/` in `modules/`, hand-curate top-level imports (avoid over-discovery).
