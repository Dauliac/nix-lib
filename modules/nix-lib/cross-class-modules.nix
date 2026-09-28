# `flake.crossClassModules`  -  declarative multi-class module registration.
#
# Contribute a small attrset per file:
#
#   { ... }: {
#     flake.crossClassModules.foo = {
#       classes = [ "nixos" "homeManager" "systemManager" ];
#       module  = { lib, ... }: { options.foo = ...; };
#     };
#   }
#
# The aggregator below derives `flake.modules.<class>.foo` for every
# declared class from this one contribution. Same body, three class
# keys, one file  -  no per-class boilerplate at the call site.
#
# Asymmetric case: register on a subset of classes by listing only
# those in `classes`. The absence of a class-cell is expressed as
# data, not as file duplication or code branches:
#
#   flake.crossClassModules.bar = {
#     classes = [ "nixos" "systemManager" ];  # HM absent
#     module  = { lib, ... }: { options.bar = ...; };
#   };
#
# Compose across atomic entries: use `includes = [ "subA" "subB" ]`
# to fold their per-class module bodies into this entry's class-cells.
# The aggregator filters `includes` per-class by intersecting with
# each included entry's own `classes`  -  so the composer writes ONE
# unfiltered `includes` list and asymmetry propagates automatically.
#
#   flake.crossClassModules.composer = {
#     classes  = [ "nixos" "homeManager" "systemManager" ];
#     includes = [ "foo" "bar" ];      # bar's HM cell is silently dropped
#     module   = { pkgs, ... }: { _module.args.x = ...; };
#   };
#
# Interop fallback: if an `includes` name is NOT declared under
# `crossClassModules` (a hand-written `flake.modules.<class>.<name>`
# entry from elsewhere), the aggregator falls back to the module-tree
# lookup and includes it unconditionally. Lets a repo migrate its
# cross-class registrations tier-by-tier without breaking `includes`
# lists that reference not-yet-migrated names.
#
# Rationale for the primitive shape (option + config aggregator, not
# a helper function): consumer sites contribute pure data and do not
# grow any `import` lines or helper-invocation lines. Discovery of
# every contribution flows through the module system's ordinary merge.
# See `openspec/changes/cross-class-modules-primitive/design.md` for
# the full decision record.
{ lib, config, ... }:
{
  options.flake.crossClassModules = lib.mkOption {
    default = { };
    description = ''
      Deferred modules registered on multiple `flake.modules.<class>`
      keys, declared as pure data. Each entry lists the classes it
      applies to, the module body, and optionally the names of other
      entries whose class-cells to compose in.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          classes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = ''
              Class names under which the module is registered.
              Common values: "nixos", "homeManager", "systemManager",
              "darwin", "nixvim". Free-form; the primitive does not
              validate against a fixed set.
            '';
          };
          module = lib.mkOption {
            type = lib.types.deferredModule;
            default = { };
            description = ''
              The module body registered on each class cell. The same
              value is reused across all classes in `classes`.
            '';
          };
          includes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              Names of other `crossClassModules` entries whose per-class
              module bodies to fold into this entry's class-cells. The
              aggregator filters per class by intersecting with each
              included entry's own `classes`. If a name is not present
              in `crossClassModules`, the aggregator falls back to a
              direct lookup in `config.flake.modules.<class>.<name>`.
            '';
          };
        };
      }
    );
  };

  config.flake.modules = lib.mkMerge (
    lib.mapAttrsToList (
      name: def:
      lib.genAttrs def.classes (class: {
        ${name} = {
          imports = [
            def.module
          ]
          ++ (
            let
              # For each included name: if it's in crossClassModules,
              # keep only when the target class is in its own `classes`.
              # If it's NOT in crossClassModules, keep unconditionally
              # (interop with hand-written flake.modules.<class>.<name>).
              keep =
                n:
                let
                  cm = config.flake.crossClassModules.${n} or null;
                in
                cm == null || builtins.elem class cm.classes;
              lookup = n: config.flake.modules.${class}.${n};
            in
            map lookup (lib.filter keep def.includes)
          );
        };
      })
    ) config.flake.crossClassModules
  );
}
