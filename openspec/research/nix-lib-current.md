# nix-lib current-state audit

Snapshot taken 2026-09-26 against `main` (commit around 744da1d).
Companion to `nix-oci-audit.md`, `import-tree.md`, `flake-parts-partitions.md`.

## 1. Repository layout

```
nix-lib/
├── flake.nix                       # entry point, 42 lines
├── modules/
│   ├── nix-lib-outputs.nix         # flakeModules.{default,pure} + adapters
│   ├── systems.nix                 # inlined nix-systems/default
│   ├── partitions.nix              # dev-partition wiring
│   ├── _dev/                       # dev partition (full nixpkgs)
│   │   ├── flake.nix               # dev-side inputs (nixpkgs, treefmt, backends)
│   │   ├── module.nix              # dev module (packages, devShells, checks)
│   │   └── scenario-checks.nix
│   └── nix-lib/
│       ├── _lib/                   # private factory: mk*, eval*, backends, coverage
│       ├── _all.nix                # hand-maintained list of option modules
│       ├── _default.nix            # hand-maintained: full API (docs + per-system)
│       ├── _pure.nix               # hand-maintained: pure API (no pkgs)
│       ├── enable.nix
│       ├── namespace.nix
│       ├── coverage.nix
│       ├── adapterDefs/
│       │   ├── default.nix         # hand-maintained: imports builtins/*.nix
│       │   ├── builtins/           # 7 files (nixos, home-manager, ...)
│       │   └── _types/             # option types
│       ├── collectors/             # 4 files
│       ├── lib/                    # flake.nix, internal.nix, perSystem.nix
│       ├── legacyPackages/         # lib.nix, nix-lib.nix
│       ├── testing/                # backend.nix, reporter.nix, outputPath.nix
│       ├── tests/                  # tests/flake.nix
│       └── docs/                   # enableOutput.nix, package.nix, _markdown.nix
├── examples/                       # 15 files, consumer-facing
├── tests/                          # BDD + 5 E2E scenario subflakes
├── dev/                            # legacy dev holder (unused now?)
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

## 2. flake.nix walkthrough

```nix
outputs = inputs:
  let
    lib = inputs.nixpkgs-lib.lib;
    nlibLib = import ./modules/nix-lib/_lib { inherit lib; };
    result = inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./modules/nix-lib-outputs.nix
        ./modules/systems.nix
        ./modules/partitions.nix
      ];
    };
  in
  result
  // {
    lib = (result.lib or { }) // {
      inherit (nlibLib)
        mkFlake evalLibModules mkSpecialArgsLib mkLib mkAdapter withLib;
    };
  };

inputs = {
  flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-lib";
  flake-parts.url = "github:hercules-ci/flake-parts";
  nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
};
```

- Only two consumer-visible inputs: `flake-parts`, `nixpkgs-lib` (both lightweight).
- Three internal flake modules imported: `nix-lib-outputs.nix`, `systems.nix`, `partitions.nix`.
- `nlibLib` is a private factory imported outside `mkFlake` and merged post hoc into `.lib`.

## 3. modules/partitions.nix (already partition-aware)

```nix
{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.partitions ];
  partitionedAttrs = {
    packages = "dev";
    checks = "dev";
    devShells = "dev";
    formatter = "dev";
  };
  partitions.dev = {
    extraInputsFlake = ./_dev;
    module = ./_dev/module.nix;
  };
}
```

- `modules/_dev/flake.nix` is the extraInputsFlake and holds pkgs-dependent inputs (nixpkgs, nix-unit, treefmt-nix, devour-flake, get-flake, flake-file, nixtest, nix-tests, nixt, namaka).
- Consumers of `nix-lib` never fetch any of the above.

## 4. What escapes to consumers

Inputs the consumer's lock ends up with:
- `flake-parts`
- `nixpkgs-lib`

Outputs the consumer's `nix flake show` reveals (based on flake.nix):
- `lib.mkFlake`
- `lib.evalLibModules`
- `lib.mkSpecialArgsLib`
- `lib.mkLib`
- `lib.mkAdapter`
- `lib.withLib`
- `flakeModules.default`
- `flakeModules.pure`
- `nixosModules.default`
- `homeModules.default`
- `darwinModules.default`
- `nixvimModules.default`
- `systemManagerModules.default`
- `wrapperModules.default`
- possibly `lib.<per-system>.*` merged from `flake.lib` (via `flakeModules.default` at consumer eval time)

Outputs hidden by the dev partition:
- `packages.nix-lib-docs`
- `checks.tests`
- `devShells.default`
- `formatter`

## 5. Public API contract (must not break)

The README documents these entry points. Their signatures MUST stay stable:
- `lib.mkFlake { ... } { ... }`
- `lib.mkAdapter { name = "nixos"; ... }`
- `lib.evalLibModules { ... }`
- `lib.mkLib { ... }`, `lib.mkSpecialArgsLib { ... }`, `lib.withLib { ... }`
- `flakeModules.default`, `flakeModules.pure`
- All `<system>Modules.default` from mkAdapter

Lib-definition option shape:
```
nix-lib.lib.<name> = { fn, description?, tests?, type?, visible? };
```

## 6. Pain points that motivate the refactor

### 6.1 Three hand-maintained import lists

`modules/nix-lib/_default.nix` (14 lines, 13 imports):
```nix
imports = [
  ./_all.nix
  ./adapterDefs
  ./collectors/collectorDefs.nix
  ./collectors/metaCollectors.nix
  ./collectors/systemCollectors.nix
  ./lib/flake.nix
  ./lib/perSystem.nix
  ./tests/flake.nix
  ./legacyPackages/lib.nix
  ./legacyPackages/nix-lib.nix
  ./docs/enableOutput.nix
  ./docs/package.nix
];
```

`modules/nix-lib/_pure.nix` (12 imports, subset of `_default` minus per-system, docs).

`modules/nix-lib/_all.nix` (7 imports):
```nix
imports = [
  ./enable.nix
  ./namespace.nix
  ./testing/backend.nix
  ./testing/reporter.nix
  ./testing/outputPath.nix
  ./coverage.nix
  ./lib/internal.nix
];
```

Adding a new option module means editing up to 3 files. Some modules exist in one list but not the other with no readable convention explaining why.

### 6.2 adapterDefs list is another hand-maintained list

`modules/nix-lib/adapterDefs/default.nix` imports:
```nix
imports = [
  ./builtins/nixos.nix
  ./builtins/home-manager.nix
  ./builtins/nix-darwin.nix
  ./builtins/nixvim.nix
  ./builtins/system-manager.nix
  ./builtins/wrappers.nix
  ./builtins/perSystem.nix
];
```

Adding a new builtin adapter requires editing this file (and touching `nix-lib-outputs.nix` if the adapter is meant to be exposed as `flake.<name>Modules.default`).

### 6.3 mkAdapter.nix hardcodes _all.nix

`modules/nix-lib/_lib/mkAdapter.nix:237`:
```nix
imports = [ ../_all.nix ];
```

The factory has an unavoidable dependency on the `_all.nix` list, so mkAdapter cannot be moved or reused in isolation.

### 6.4 Dev-side scenario discovery is manual

`tests/scenarios/` holds 5 subflake scenarios. Adding a new one requires editing the dev partition to wire it in. Auto-discovery via `import-tree` would remove the wiring step.

### 6.5 No import-tree usage today

Currently `import-tree` is not an input, not vendored, not used. Every glob-like discovery is done by hand.

## 7. Sources cross-checked with disk

Verified all of the above by:
- Reading `flake.nix` (42 lines).
- Reading `modules/partitions.nix`, `modules/nix-lib-outputs.nix`, `modules/systems.nix`.
- Reading `modules/nix-lib/_default.nix`, `_pure.nix`, `_all.nix`.
- Reading `modules/nix-lib/adapterDefs/default.nix`.
- Running `find modules -name '*.nix'` to enumerate the 50-plus module files.
- Grepping `modules/nix-lib/_lib/mkAdapter.nix` for `imports\|_all\|adapterDefs`.

All citations resolve to files present at `main` HEAD.
