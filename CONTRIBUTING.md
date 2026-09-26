# Contributing to nix-lib

## Development Setup

```bash
# Clone the repository
git clone https://github.com/Dauliac/nix-lib
cd nix-lib

# Enter dev shell
nix develop
```

## Running Tests

Tests are located in the `tests/` directory and run against the examples.

```bash
# Run all checks
cd tests
nix run "build-all"

# Build all test derivations
nix run .#build-all
```

## Project Structure

```
nix-lib/
├── modules/                 # Core nix-lib modules
│   ├── nix-lib/             # Main module implementation
│   │   ├── _lib/            # Internal library (mkAdapter, types, vendored import-tree)
│   │   ├── _default.nix     # Full API entry point (auto-discovered)
│   │   ├── _pure.nix        # Pure API entry point (no pkgs)
│   │   ├── enable.nix       # Core options...
│   │   ├── namespace.nix
│   │   ├── coverage.nix
│   │   ├── testing/         # Auto-discovered
│   │   ├── lib/             # Auto-discovered
│   │   ├── adapterDefs/     # Adapter definitions (builtins/ auto-discovered)
│   │   ├── collectors/      # Auto-discovered
│   │   ├── docs/            # Auto-discovered
│   │   └── legacyPackages/  # Auto-discovered
│   └── nix-lib-outputs.nix  # Flake outputs (adapters)
├── examples/                # Example configurations
├── tests/                   # Integration tests
└── openspec/                # Design docs and change proposals
```

### File-naming convention (internal auto-discovery)

`modules/nix-lib/_default.nix` and `modules/nix-lib/_pure.nix` walk
`modules/nix-lib/` via the vendored `import-tree` at
`modules/nix-lib/_lib/import-tree/`. Discovery follows two rules:

1. Any `.nix` file whose path contains `/_` (a directory or file
   whose basename starts with `_`) is **skipped**. This is how
   private helpers (`_lib/`, `_types/`, `_factory.nix`,
   `_markdown.nix`) stay out of the flake-parts import set.
2. Every other `.nix` file becomes a live flake-parts module.

Adding a new option module: drop a `.nix` file anywhere under
`modules/nix-lib/` whose name and path do not use the `_` prefix. It
will be picked up on the next eval. No index file needs editing.

Adding a new adapter builtin: drop a `.nix` file under
`modules/nix-lib/adapterDefs/builtins/`. `adapterDefs/default.nix`
walks that directory via `import-tree`.

### Refreshing the vendored `import-tree`

The upstream is `github:denful/import-tree`
(Apache License 2.0). To refresh:

```bash
COMMIT=<sha>
curl -sSL \
  "https://raw.githubusercontent.com/denful/import-tree/$COMMIT/default.nix" \
  > modules/nix-lib/_lib/import-tree/default.nix
curl -sSL \
  "https://raw.githubusercontent.com/denful/import-tree/$COMMIT/tests.nix" \
  > modules/nix-lib/_lib/import-tree/tests.nix
# Re-prepend the attribution header on each file. Update the pinned
# commit hash in the header. Then run `nix flake check`.
```

The full upstream LICENSE lives at
`modules/nix-lib/_lib/import-tree/LICENSE`. Keep it in sync with the
pinned commit if the upstream license ever changes.

## Adding a New Adapter

1. Add the adapter name to `namespaces` in `modules/nix-lib/_lib/mkAdapter.nix`
2. Add nested system configuration if applicable in `nestedSystems`
3. Export the module in `modules/nix-lib-outputs.nix`
4. Add an example in `examples/`
5. Add tests in `tests/flake.nix`

## Test Format

Tests are defined inline with lib definitions:

```nix
nix-lib.lib.myFunc = {
  type = lib.types.functionTo lib.types.int;
  fn = x: x * 2;
  description = "Double a number";
  tests."doubles 5" = {
    args.x = 5;
    expected = 10;
  };
};
```

Tests run at evaluation time using pure Nix assertions.
