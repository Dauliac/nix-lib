# Contributing to nlib

## Development Setup

```bash
# Clone the repository
git clone https://github.com/Dauliac/nlib
cd nlib

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
nlib/
├── modules/           # Core nlib modules
│   ├── nlib/          # Main module implementation
│   │   ├── _lib/      # Internal library (mkAdapter, types)
│   │   └── _all.nix   # Common options
│   └── nlib-outputs.nix  # Flake outputs (adapters)
├── examples/          # Example configurations
│   ├── flake-parts.nix
│   ├── nixos.nix
│   ├── home-manager.nix
│   └── ...
└── tests/             # Integration tests
    └── flake.nix
```

## Adding a New Adapter

1. Add the adapter name to `namespaces` in `modules/nlib/_lib/mkAdapter.nix`
2. Add nested system configuration if applicable in `nestedSystems`
3. Export the module in `modules/nlib-outputs.nix`
4. Add an example in `examples/`
5. Add tests in `tests/flake.nix`

## Test Format

Tests are defined inline with lib definitions:

```nix
nlib.lib.myFunc = {
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
