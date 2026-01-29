# nlib

A Nix module system for defining library functions with types, tests, and documentation in one place.

## Problem

Nix library code tends to be scattered: functions in one file, tests somewhere else (or nowhere), types implicit, documentation in comments that rot. When libraries grow, this becomes hard to maintain and harder to trust.

## Solution

nlib treats library functions as module options. Each function bundles its implementation, type signature, tests, and description together:

```nix
nlib.lib.double = {
  type = lib.types.functionTo lib.types.int;
  fn = x: x * 2;
  description = "Double a number";
  tests."doubles 5" = {
    args.x = 5;
    expected = 10;
  };
};
```

The function is then available as a plain function at `config.lib.flake.double`.

This approach:
- Forces tests to exist alongside code
- Makes types explicit and checkable
- Keeps documentation next to what it documents
- Uses the NixOS module system for composition

## Usage

### flake-parts

```nix
{
  inputs.nlib.url = "github:Dauliac/nlib";

  outputs = inputs:
    inputs.nlib.inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nlib.flakeModules.default ];

      # Define at nlib.lib.<name>
      nlib.lib.add = {
        type = lib.types.functionTo (lib.types.functionTo lib.types.int);
        fn = a: b: a + b;
        description = "Add two integers";
        tests."adds 2 and 3" = {
          args = { a = 2; b = 3; };
          expected = 5;
        };
      };

      # Use at config.lib.flake.<name>
      # Output at flake.lib.flake.<name>
    };
}
```

### NixOS, home-manager, nix-darwin, nixvim

```nix
{ config, lib, ... }:
{
  imports = [ nlib.nixosModules.default ];
  nlib.enable = true;

  nlib.lib.openPort = {
    type = lib.types.functionTo lib.types.attrs;
    fn = port: { networking.firewall.allowedTCPPorts = [ port ]; };
    description = "Open a TCP port";
    tests."opens 80" = {
      args.port = 80;
      expected = { networking.firewall.allowedTCPPorts = [ 80 ]; };
    };
  };

  # Use the lib
  imports = [ (config.lib.openPort 443) ];
}
```

Available modules:
- `nlib.nixosModules.default`
- `nlib.homeModules.default`
- `nlib.darwinModules.default`
- `nlib.nixvimModules.default`

### Per-system libs (with pkgs)

```nix
perSystem = { pkgs, lib, config, ... }: {
  nlib.lib.mkScript = {
    type = lib.types.functionTo (lib.types.functionTo lib.types.package);
    fn = name: script: pkgs.writeShellScriptBin name script;
    description = "Create a shell script package";
    tests."creates hello" = {
      args = { name = "hello"; script = "echo hi"; };
      expected = "hello";
    };
  };

  packages.greet = config.lib.mkScript "greet" "echo hello";
};
```

## Output structure

```
flake.lib.flake.<name>                          # Pure flake libs
flake.lib.nixos.<name>                          # NixOS libs (collected)
flake.lib.home.<name>                           # home-manager libs (collected)
flake.lib.darwin.<name>                         # nix-darwin libs (collected)
flake.lib.vim.<name>                            # nixvim libs (collected)
legacyPackages.<system>.nlib.<name>             # Per-system libs
```

## Running tests

```nix
nlib.testing = {
  backend = "nix-unit";
  reporter = "junit";
  outputPath = "test-results.xml";
};
```

```bash
nix-unit --flake .#tests.lib
```

## Lib definition options

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `type` | Nix type | Yes | Function type |
| `fn` | function | Yes | Implementation |
| `description` | string | Yes | What it does |
| `tests` | attrset | No | Test cases |
| `example` | string | No | Example usage |
| `visible` | bool | No | Show in docs (default: true) |

## Status

This is experimental. The API may change.

## Contributing

Contributions welcome. Areas that need work:

- Better error messages when types don't match
- More test backends
- Documentation generation from lib definitions
- Performance with large numbers of libs

If you find bugs or have ideas, open an issue or PR.

See `examples/` and `tests/integration/` for working examples.
