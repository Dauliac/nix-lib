# nlib

A Nix library framework implementing the **Lib Modules Pattern** - where library functions are defined as module options with built-in types, tests, and documentation.

## The Problem

Writing Nix libraries typically means:
- Functions scattered across files with no consistent structure
- Tests living separately (or not existing at all)
- Types and documentation as afterthoughts
- No standard way to compose libraries

## The Solution: Lib Modules Pattern

Instead of defining functions separately from their specifications, define them as **config values** that bundle everything together:

```nix
# Define at nlib.lib.<name> with full metadata
nlib.lib.double = {
  type = lib.types.functionTo lib.types.int;
  fn = x: x * 2;
  description = "Double a number";
  tests."doubles 5" = {
    args.x = 5;
    expected = 10;
  };
};

# Use via lib.flake.<name> (plain function)
result = config.lib.flake.double 5;  # => 10
```

This gives you:
- **Type safety** - explicit Nix types for your functions
- **Built-in testing** - tests live with the code, impossible to forget
- **Documentation** - descriptions and examples in one place
- **Composition** - use the NixOS module system to combine libraries
- **LSP support** - proper option types enable autocomplete and hover info

## Quick Start

### With flake-parts

```nix
{
  inputs.nlib.url = "github:Dauliac/nlib";

  outputs = inputs:
    inputs.nlib.inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nlib.flakeModules.default ];

      # Define pure libs at nlib.lib.<name>
      nlib.lib.add = {
        type = lib.types.functionTo (lib.types.functionTo lib.types.int);
        fn = a: b: a + b;
        description = "Add two integers";
        tests."adds 2 and 3" = {
          args = { a = 2; b = 3; };
          expected = 5;
        };
      };

      # Per-system libs (depend on pkgs)
      perSystem = { pkgs, lib, config, ... }: {
        # Define at nlib.lib.<name>
        nlib.lib.writeGreeting = {
          type = lib.types.functionTo lib.types.package;
          fn = name: pkgs.writeText "greeting-${name}" "Hello, ${name}!";
          description = "Create a greeting file";
          tests."greets Alice" = {
            args.name = "Alice";
            expected = "greeting-Alice";
          };
        };

        # Use via config.lib.<name>
        packages.greeting = config.lib.writeGreeting "World";
      };
    };
}
```

**API Pattern:**
- **Define** at `nlib.lib.<name>` with `{ type, fn, description, tests }`
- **Use** via `lib.<namespace>.<name>` (plain function)

Your functions are available at:
- `flake.lib.flake.<name>` - pure flake libs
- `legacyPackages.${system}.nlib.<name>` - per-system libs

### With NixOS, home-manager, or other module systems

```nix
{ config, lib, ... }:
{
  imports = [ nlib.nixosModules.default ];

  nlib.enable = true;

  # Define at nlib.lib.<name>
  nlib.lib.triple = {
    type = lib.types.functionTo lib.types.int;
    fn = x: x * 3;
    description = "Triple a number";
    tests."triples 4" = {
      args.x = 4;
      expected = 12;
    };
  };

  # Use via config.lib.<name>
  environment.etc."tripled".text = toString (config.lib.triple 7);  # => "21"
}
```

Available modules:
- `nlib.nixosModules.default` - define at `nlib.lib.*`, use at `config.lib.*`, exports to `flake.lib.nixos.*`
- `nlib.homeModules.default` - define at `nlib.lib.*`, use at `config.lib.*`, exports to `flake.lib.home.*`
- `nlib.nixvimModules.default` - define at `nlib.lib.*`, use at `config.lib.*`, exports to `flake.lib.vim.*`
- `nlib.darwinModules.default` - define at `nlib.lib.*`, use at `config.lib.*`, exports to `flake.lib.darwin.*`

## Output Structure

Following the [dendritic pattern](https://github.com/mightyiam/dendritic), libs are organized by namespace:

```
# Flake outputs (plain functions)
flake.lib.flake.add            # Pure flake libs (from nlib.lib.*)
flake.lib.nixos.helper         # NixOS libs (from nixosConfigurations)
flake.lib.home.util            # Home-manager libs
flake.lib.vim.mapping          # Nixvim libs
flake.lib.darwin.service       # Nix-darwin libs
legacyPackages.x86_64-linux.nlib.writeGreeting  # Per-system libs

# Within module scope (plain functions)
config.lib.flake.<name>        # In flake-parts scope
config.lib.<name>              # In NixOS/home-manager/darwin/nixvim scope
```

## Running Tests

Configure the test backend and run with nix-unit:

```nix
nlib.testing = {
  backend = "nix-unit";  # also: "nixt", "nixtest", "runTests"
  reporter = "junit";    # for CI integration
  outputPath = "test-results.xml";
};
```

```bash
nix-unit --flake .#tests.lib
```

## Test Formats

Simple expected value:
```nix
tests."test name" = {
  args.x = 5;
  expected = 10;
};
```

Multiple assertions (lazily evaluated):
```nix
tests."test name" = {
  args.x = 5;
  assertions = [
    { name = "is positive"; check = result: result > 0; }
    { name = "is even"; check = result: lib.mod result 2 == 0; }
    { name = "equals 10"; expected = 10; }
  ];
};
```

## Lib Definition Options

Each lib definition accepts:

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `type` | Nix type | Yes | Function type (e.g., `lib.types.functionTo lib.types.int`) |
| `fn` | function | Yes | The function implementation |
| `description` | string | Yes | What the function does |
| `tests` | attrset | No | Test cases (default: `{}`) |
| `example` | string | No | Optional example usage |
| `visible` | bool | No | Show in documentation (default: `true`) |

## Why This Pattern?

Traditional Nix libraries separate concerns: code here, tests there, docs somewhere else. The Lib Modules Pattern keeps everything together. When you write a function, you write its type, its tests, and its documentation in the same place.

This makes it:
- **Harder to skip tests** - they're part of the function definition
- **Easier to understand** - everything about a function is in one place
- **Simpler to maintain** - change the function, update the test right there
- **Ready to compose** - modules merge naturally with the NixOS module system
- **LSP friendly** - proper types enable IDE features

## See Also

- `tests/integration/` - Complete example with flake-parts, NixOS, and per-system libs
- `tests/` - nlib's own tests using the pattern
