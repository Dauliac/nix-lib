# Cross-class module registration primitive  -  BDD style flake-parts module.
#
# Each test spins up a mini flake-parts evaluation via `lib.evalModules`,
# loads the primitive module `modules/nix-lib/cross-class-modules.nix`
# plus a small in-line consumer, then asserts on the derived
# `config.flake.modules` shape.
#
# The primitive lives at `modules/nix-lib/cross-class-modules.nix`; the
# design record is at `openspec/changes/cross-class-modules-primitive/design.md`.
{ lib, ... }:
let
  primitive = ../../modules/nix-lib/cross-class-modules.nix;

  # Minimal flake-parts-shaped harness so the primitive can declare
  # `options.flake.crossClassModules` and derive `config.flake.modules`
  # without pulling the real flake-parts flake evaluation.
  harness = { lib, ... }: {
    options.flake = lib.mkOption {
      type = lib.types.submodule (
        { ... }: {
          freeformType = lib.types.lazyAttrsOf lib.types.raw;
          options.modules = lib.mkOption {
            type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.deferredModule);
            default = { };
          };
        }
      );
      default = { };
    };
  };

  eval =
    consumer:
    (lib.evalModules {
      modules = [
        harness
        primitive
        consumer
      ];
    }).config;

  # 1. Symmetric case: one module on three classes.
  symmetric = eval (
    { ... }: {
      flake.crossClassModules.foo = {
        classes = [
          "nixos"
          "homeManager"
          "systemManager"
        ];
        module = { lib, ... }: { options.foo = lib.mkEnableOption "foo"; };
      };
    }
  );

  # 2. Asymmetric case: one module on two classes, HM absent.
  asymmetric = eval (
    { ... }: {
      flake.crossClassModules.bar = {
        classes = [
          "nixos"
          "systemManager"
        ];
        module = { lib, ... }: { options.bar = lib.mkEnableOption "bar"; };
      };
    }
  );

  # 3. Includes with per-class filter: composer references subA (both
  # classes) and subB (nixos only). Composer's HM cell must drop subB.
  composed = eval (
    { ... }: {
      flake.crossClassModules.subA = {
        classes = [
          "nixos"
          "homeManager"
        ];
        module = { lib, ... }: { options.subA = lib.mkEnableOption "subA"; };
      };
      flake.crossClassModules.subB = {
        classes = [ "nixos" ];
        module = { lib, ... }: { options.subB = lib.mkEnableOption "subB"; };
      };
      flake.crossClassModules.composer = {
        classes = [
          "nixos"
          "homeManager"
        ];
        includes = [
          "subA"
          "subB"
        ];
        module = { ... }: { };
      };
    }
  );

  # 4. Interop fallback: composer includes a name that is NOT declared
  # via `crossClassModules`  -  it's a hand-written `flake.modules.nixos.legacy`
  # from an earlier tier. Fallback must include it unconditionally.
  interop = eval (
    { lib, ... }: {
      flake.modules.nixos.legacy = { lib, ... }: {
        options.legacy = lib.mkEnableOption "legacy";
      };
      flake.crossClassModules.wrapper = {
        classes = [ "nixos" ];
        includes = [ "legacy" ];
        module = { ... }: { };
      };
    }
  );

  # `flake.modules.<class>` presence check: an entry exists iff a
  # class-cell was emitted by the aggregator.
  hasEntry =
    mods: class: name:
    (mods ? ${class}) && (mods.${class} ? ${name});

  # Count real class-cells for a name across a known class set.
  classCount =
    mods: name: classes:
    lib.length (lib.filter (c: hasEntry mods c name) classes);

  results = {
    # 1. Symmetric
    symmetric_nixos = hasEntry symmetric.flake.modules "nixos" "foo";
    symmetric_homeManager = hasEntry symmetric.flake.modules "homeManager" "foo";
    symmetric_sysManager = hasEntry symmetric.flake.modules "systemManager" "foo";
    symmetric_count = classCount symmetric.flake.modules "foo" [
      "nixos"
      "homeManager"
      "systemManager"
    ];

    # 2. Asymmetric
    asymmetric_nixos = hasEntry asymmetric.flake.modules "nixos" "bar";
    asymmetric_sysManager = hasEntry asymmetric.flake.modules "systemManager" "bar";
    asymmetric_hm_absent = !(hasEntry asymmetric.flake.modules "homeManager" "bar");

    # 3. Composed with includes filter
    composed_nixos_composer = hasEntry composed.flake.modules "nixos" "composer";
    composed_hm_composer = hasEntry composed.flake.modules "homeManager" "composer";
    composed_nixos_has_subA = hasEntry composed.flake.modules "nixos" "subA";
    composed_nixos_has_subB = hasEntry composed.flake.modules "nixos" "subB";
    composed_hm_has_subA = hasEntry composed.flake.modules "homeManager" "subA";
    composed_hm_subB_absent = !(hasEntry composed.flake.modules "homeManager" "subB");

    # 4. Interop fallback
    interop_nixos_legacy_kept = hasEntry interop.flake.modules "nixos" "legacy";
    interop_nixos_wrapper_kept = hasEntry interop.flake.modules "nixos" "wrapper";
  };
in
{
  flake.tests = {
    # 1. Symmetric case
    "test_crossClassModules_symmetric_registers_on_nixos" = {
      expr = results.symmetric_nixos;
      expected = true;
    };
    "test_crossClassModules_symmetric_registers_on_homeManager" = {
      expr = results.symmetric_homeManager;
      expected = true;
    };
    "test_crossClassModules_symmetric_registers_on_systemManager" = {
      expr = results.symmetric_sysManager;
      expected = true;
    };
    "test_crossClassModules_symmetric_registers_on_exactly_three_classes" = {
      expr = results.symmetric_count;
      expected = 3;
    };

    # 2. Asymmetric case
    "test_crossClassModules_asymmetric_registers_on_nixos" = {
      expr = results.asymmetric_nixos;
      expected = true;
    };
    "test_crossClassModules_asymmetric_registers_on_systemManager" = {
      expr = results.asymmetric_sysManager;
      expected = true;
    };
    "test_crossClassModules_asymmetric_absent_on_homeManager" = {
      expr = results.asymmetric_hm_absent;
      expected = true;
    };

    # 3. Composed with per-class filter
    "test_crossClassModules_composed_nixos_has_composer" = {
      expr = results.composed_nixos_composer;
      expected = true;
    };
    "test_crossClassModules_composed_homeManager_has_composer" = {
      expr = results.composed_hm_composer;
      expected = true;
    };
    "test_crossClassModules_composed_subA_visible_on_nixos" = {
      expr = results.composed_nixos_has_subA;
      expected = true;
    };
    "test_crossClassModules_composed_subB_visible_on_nixos" = {
      expr = results.composed_nixos_has_subB;
      expected = true;
    };
    "test_crossClassModules_composed_subA_visible_on_homeManager" = {
      expr = results.composed_hm_has_subA;
      expected = true;
    };
    "test_crossClassModules_composed_subB_absent_on_homeManager" = {
      expr = results.composed_hm_subB_absent;
      expected = true;
    };

    # 4. Interop fallback
    "test_crossClassModules_interop_hand_written_legacy_preserved" = {
      expr = results.interop_nixos_legacy_kept;
      expected = true;
    };
    "test_crossClassModules_interop_wrapper_registered" = {
      expr = results.interop_nixos_wrapper_kept;
      expected = true;
    };
  };
}
