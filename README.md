# nlib

A Nix library framework implementing the **Lib Modules Pattern** - where library functions are defined as module options with built-in types, tests, and documentation.

## The Problem

Writing Nix libraries typically means:
- Functions scattered across files with no consistent structure
- Tests living separately (or not existing at all)
- Types and documentation as afterthoughts
- No standard way to compose libraries

## The Solution: Lib Modules Pattern

Define functions as **config values** that bundle everything together:

```nix
nlib.lib.double = {
  type = lib.types.functionTo lib.types.int;
  fn = x: x * 2;
  description = "Double a number";
  tests."doubles 5" = { args.x = 5; expected = 10; };
};
```

This gives you:
- **Type safety** - explicit Nix types for your functions
- **Built-in testing** - tests live with the code
- **Documentation** - descriptions in one place
- **Composition** - use the NixOS module system to combine libraries
- **Nested propagation** - libs from nested modules (home-manager in NixOS) are accessible in parent scope

## Quick Start

### With flake-parts

```nix
{
  inputs.nlib.url = "github:Dauliac/nlib";

  outputs = inputs:
    inputs.nlib.inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nlib.flakeModules.default ];

      nlib.lib.add = {
        type = lib.types.functionTo lib.types.int;
        fn = { a, b }: a + b;
        description = "Add two integers";
        tests."adds 2 and 3" = { args.x = { a = 2; b = 3; }; expected = 5; };
      };
    };
}
```

### With NixOS

```nix
{ config, lib, ... }:
{
  imports = [
    nlib.nixosModules.default
    nlib.nixosModules.libShorthand  # enables config.lib.* shorthand
  ];

  nlib.lib.triple = {
    type = lib.types.functionTo lib.types.int;
    fn = x: x * 3;
    description = "Triple a number";
    tests."triples 4" = { args.x = 4; expected = 12; };
  };

  # Use the function
  environment.etc."tripled".text = toString (config.lib.triple 7);  # => "21"
}
```

## API Reference

### Defining Libraries

Define libs at `nlib.lib.<name>` (supports nested namespaces like `nlib.lib.utils.helper`):

```nix
nlib.lib.myFunc = {
  type = lib.types.functionTo lib.types.int;  # Required: function signature
  fn = x: x * 2;                               # Required: implementation
  description = "What it does";                # Required: documentation
  tests."test name" = {                        # Optional: test cases
    args.x = 5;
    expected = 10;
  };
  visible = true;                              # Optional: public (true) or private (false)
};
```

### Lib Output Layers

Libs defined in different module systems are available at different paths. This table shows where libs are accessible depending on where they are defined:

#### Flake-Level Libs (pure, no pkgs)

| Defined in | Module to import | Access within module | Flake output |
|------------|------------------|---------------------|--------------|
| flake-parts `nlib.lib.*` | `flakeModules.default` | `config.lib.flake.<name>` | `flake.lib.flake.<name>` |
| perSystem `nlib.lib.*` | `flakeModules.default` | `config.lib.<name>` | `legacyPackages.<system>.nlib.<name>` |

#### System Configuration Libs

| Defined in | Module to import | Access within module | With libShorthand | Flake output |
|------------|------------------|---------------------|-------------------|--------------|
| NixOS `nlib.lib.*` | `nixosModules.default` | `config.nlib.fns.<name>` | `config.lib.<name>` | `flake.lib.nixos.<name>` |
| home-manager `nlib.lib.*` | `homeModules.default` | `config.nlib.fns.<name>` | `config.lib.<name>` (built-in) | `flake.lib.home.<name>` |
| nix-darwin `nlib.lib.*` | `darwinModules.default` | `config.nlib.fns.<name>` | `config.lib.<name>` | `flake.lib.darwin.<name>` |
| nixvim `nlib.lib.*` | `nixvimModules.default` | `config.nlib.fns.<name>` | `config.lib.<name>` | `flake.lib.vim.<name>` |
| system-manager `nlib.lib.*` | `systemManagerModules.default` | `config.nlib.fns.<name>` | `config.lib.<name>` | `flake.lib.system.<name>` |

### Nested Module Propagation

When a parent module imports a nested module system, the nested libs are automatically accessible in the parent scope under a namespace prefix.

#### Nested Libs Access Table

| Parent module | Nested module | Libs defined in nested | Access in parent |
|---------------|---------------|------------------------|------------------|
| NixOS | home-manager | `nlib.lib.foo` | `config.nlib.fns.home.foo` or `config.lib.home.foo` |
| NixOS | home-manager → nixvim | `nlib.lib.bar` | `config.nlib.fns.home.vim.bar` or `config.lib.home.vim.bar` |
| nix-darwin | home-manager | `nlib.lib.foo` | `config.nlib.fns.home.foo` or `config.lib.home.foo` |
| nix-darwin | home-manager → nixvim | `nlib.lib.bar` | `config.nlib.fns.home.vim.bar` or `config.lib.home.vim.bar` |
| home-manager | nixvim | `nlib.lib.bar` | `config.nlib.fns.vim.bar` or `config.lib.vim.bar` |

#### Namespace Prefixes

| Module system | Namespace prefix |
|---------------|------------------|
| home-manager | `home` |
| nixvim | `vim` |
| nix-darwin | `darwin` |
| system-manager | `system` |

#### Example: NixOS with nested home-manager and nixvim

```nix
# In NixOS config (with home-manager and nixvim nested):
config.lib.enableService "openssh"              # NixOS lib
config.lib.home.mkAlias { name = "ll"; ... }    # home-manager lib (from nested)
config.lib.home.vim.mkKeymap { ... }            # nixvim lib (from nested inside home-manager)
```

### Flake Outputs Summary

All libs are collected and exported at the flake level under `flake.lib.<namespace>`:

| Namespace | Source | Description |
|-----------|--------|-------------|
| `flake.lib.flake.*` | `nlib.lib.*` in flake-parts | Pure flake-level libs |
| `flake.lib.nixos.*` | `nixosConfigurations.*.nlib.lib.*` | NixOS configuration libs |
| `flake.lib.home.*` | `homeConfigurations.*.nlib.lib.*` | Standalone home-manager libs |
| `flake.lib.darwin.*` | `darwinConfigurations.*.nlib.lib.*` | nix-darwin libs |
| `flake.lib.vim.*` | `nixvimConfigurations.*.nlib.lib.*` | Standalone nixvim libs |
| `flake.lib.system.*` | `systemConfigs.*.nlib.lib.*` | system-manager libs |

## Available Modules

### Adapter Modules

Import these to enable nlib in each module system:

| Module | Import path | Purpose |
|--------|-------------|---------|
| `flakeModules.default` | `inputs.nlib.flakeModules.default` | flake-parts integration |
| `nixosModules.default` | `nlib.nixosModules.default` | NixOS integration |
| `homeModules.default` | `nlib.homeModules.default` | home-manager integration |
| `darwinModules.default` | `nlib.darwinModules.default` | nix-darwin integration |
| `nixvimModules.default` | `nlib.nixvimModules.default` | nixvim integration |
| `systemManagerModules.default` | `nlib.systemManagerModules.default` | system-manager integration |

### Shorthand Modules (optional)

Import these alongside the adapter to enable `config.lib.*` shorthand (merges `nlib.fns` into existing `config.lib`):

| Module | Import path | Effect |
|--------|-------------|--------|
| `nixosModules.libShorthand` | `nlib.nixosModules.libShorthand` | `config.lib.<name>` → `config.nlib.fns.<name>` |
| `darwinModules.libShorthand` | `nlib.darwinModules.libShorthand` | `config.lib.<name>` → `config.nlib.fns.<name>` |
| `nixvimModules.libShorthand` | `nlib.nixvimModules.libShorthand` | `config.lib.<name>` → `config.nlib.fns.<name>` |
| `systemManagerModules.libShorthand` | `nlib.systemManagerModules.libShorthand` | `config.lib.<name>` → `config.nlib.fns.<name>` |

**Note:** home-manager already has `config.lib`, so nlib functions merge into it automatically (no separate shorthand module needed).

```nix
# Example: NixOS with libShorthand
imports = [ nlib.nixosModules.default nlib.nixosModules.libShorthand ];

# Now you can use:
config.lib.myFunc       # instead of config.nlib.fns.myFunc
config.lib.home.foo     # nested home-manager libs also available
```

## Test Formats

### Simple expected value

```nix
tests."test name" = {
  args.x = 5;       # Argument passed to fn
  expected = 10;    # Expected return value
};
```

### Multiple arguments

```nix
tests."test name" = {
  args.x = { a = 2; b = 3; };  # For fn = { a, b }: a + b
  expected = 5;
};
```

### Multiple assertions

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

## Running Tests

Configure testing backend:

```nix
nlib.testing = {
  backend = "nix-unit";
  reporter = "junit";
  outputPath = "test-results.xml";
};
```

Run tests:

```bash
# From tests directory
nix flake check
nix run .#build-all

# Or directly with nix-unit
nix-unit --flake .#tests.lib
```

## Complete Example

```nix
# flake.nix
{
  inputs = {
    nlib.url = "github:Dauliac/nlib";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = { self, nlib, nixpkgs, home-manager, ... }:
    nlib.inputs.flake-parts.lib.mkFlake { inherit (self) inputs; } {
      imports = [ nlib.flakeModules.default ];

      systems = [ "x86_64-linux" ];

      # Flake-level libs
      nlib.lib.greet = {
        type = nixpkgs.lib.types.functionTo nixpkgs.lib.types.str;
        fn = name: "Hello, ${name}!";
        description = "Generate a greeting";
        tests."greets world" = { args.name = "World"; expected = "Hello, World!"; };
      };

      # NixOS configuration
      flake.nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nlib.nixosModules.default
          nlib.nixosModules.libShorthand
          home-manager.nixosModules.home-manager
          ({ config, lib, ... }: {
            # Define NixOS-specific lib
            nlib.lib.openPort = {
              type = lib.types.functionTo lib.types.attrs;
              fn = port: { networking.firewall.allowedTCPPorts = [ port ]; };
              description = "Open a firewall port";
              tests."opens 80" = { args.port = 80; expected = { networking.firewall.allowedTCPPorts = [ 80 ]; }; };
            };

            # Use it
            imports = [ (config.lib.openPort 443) ];

            # Home-manager with nlib
            home-manager.users.myuser = { ... }: {
              imports = [ nlib.homeModules.default ];

              nlib.lib.mkAlias = {
                type = lib.types.functionTo lib.types.attrs;
                fn = { name, cmd }: { programs.bash.shellAliases.${name} = cmd; };
                description = "Create shell alias";
                tests."creates ll" = {
                  args.x = { name = "ll"; cmd = "ls -la"; };
                  expected = { programs.bash.shellAliases.ll = "ls -la"; };
                };
              };

              home.stateVersion = "24.05";
            };

            # Access home-manager libs from NixOS!
            # config.lib.home.mkAlias { name = "ll"; cmd = "ls -la"; }
          })
        ];
      };
    };
}
```

## See Also

- `examples/` - Individual examples for each module system
- `tests/` - Full integration tests
