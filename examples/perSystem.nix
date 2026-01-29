# Example: Defining libs in perSystem (with pkgs dependency)
#
# These are available at: legacyPackages.<system>.nlib.<name>
#
# Usage in flake.nix:
#   perSystem = { pkgs, lib, ... }: {
#     lib.writeGreeting = { ... };
#   };
#
{ pkgs, lib, ... }:
{
  # Per-system lib - depends on pkgs
  lib.writeGreeting = {
    type = lib.types.functionTo lib.types.package;
    fn = name: pkgs.writeText "greeting-${name}" "Hello, ${name}!";
    description = "Create a greeting file for a person";
    tests."greets Alice" = {
      args.name = "Alice";
      expected = "greeting-Alice"; # Checks derivation name
    };
  };

  lib.mkScript = {
    type = lib.types.functionTo (lib.types.functionTo lib.types.package);
    fn = name: script: pkgs.writeShellScriptBin name script;
    description = "Create a shell script package";
    tests."creates hello script" = {
      args = {
        name = "hello";
        script = "echo hello";
      };
      expected = "hello"; # Checks derivation name
    };
  };

  lib.wrapWithEnv = {
    type = lib.types.functionTo (lib.types.functionTo (lib.types.functionTo lib.types.package));
    fn =
      pkg: env: name:
      pkgs.writeShellScriptBin name ''
        export ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${v}") env)}
        exec ${pkg}/bin/${name} "$@"
      '';
    description = "Wrap a package binary with environment variables";
    tests."wraps with PATH" = {
      args = {
        pkg = pkgs.hello;
        env = {
          MY_VAR = "test";
        };
        name = "hello";
      };
      expected = "hello";
    };
  };
}
