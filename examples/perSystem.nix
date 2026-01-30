# Example: Defining libs in perSystem (with pkgs dependency)
#
# Define at: nlib.lib.<name>
# Use at: config.lib.<name> (within perSystem)
# Output at: legacyPackages.<system>.nlib.<name>
#
# Usage in flake.nix:
#   perSystem = { pkgs, lib, config, ... }: {
#     nlib.lib.writeGreeting = { ... };
#     packages.greeting = config.lib.writeGreeting "World";
#   };
#
{
  pkgs,
  lib,
  config,
  ...
}:
{
  # Per-system lib - depends on pkgs
  nlib.lib.writeGreeting = {
    type = lib.types.functionTo lib.types.package;
    fn = name: pkgs.writeText "greeting-${name}" "Hello, ${name}!";
    description = "Create a greeting file for a person";
    tests."greets Alice" = {
      args.name = "Alice";
      expected = "greeting-Alice"; # Checks derivation name
    };
  };

  nlib.lib.mkScript = {
    type = lib.types.functionTo lib.types.package;
    fn = { name, script }: pkgs.writeShellScriptBin name script;
    description = "Create a shell script package";
    tests."creates hello script" = {
      args.a = {
        name = "hello";
        script = "echo hello";
      };
      expected = "hello"; # Checks derivation name
    };
  };

  nlib.lib.wrapWithEnv = {
    type = lib.types.functionTo lib.types.package;
    fn =
      {
        pkg,
        env,
        name,
      }:
      pkgs.writeShellScriptBin name ''
        export ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${v}") env)}
        exec ${pkg}/bin/${name} "$@"
      '';
    description = "Wrap a package binary with environment variables";
    tests."wraps with PATH" = {
      args.a = {
        pkg = pkgs.hello;
        env = {
          MY_VAR = "test";
        };
        name = "hello";
      };
      expected = "hello";
    };
  };

  # ============================================================
  # Usage: Real packages using the libs (for e2e testing)
  # ============================================================

  packages = {
    # Use lib to create greeting files
    greeting-world = config.lib.writeGreeting "World";
    greeting-nix = config.lib.writeGreeting "Nix";

    # Use lib to create scripts
    say-hello = config.lib.mkScript {
      name = "say-hello";
      script = ''
        echo "Hello from nlib!"
      '';
    };
    list-files = config.lib.mkScript {
      name = "list-files";
      script = ''
        ls -la "$@"
      '';
    };

    # Use lib to wrap packages with environment
    hello-custom = config.lib.wrapWithEnv {
      pkg = pkgs.hello;
      env = {
        GREETING = "Bonjour";
      };
      name = "hello";
    };
  };
}
