# Design: `flake.crossClassModules` primitive

Change ID: `cross-class-modules-primitive`
Companion: proposal.md, tasks.md

## Decision record

### D1. Contribute via option, not via helper function

Rejected: expose a `lib.mkCrossClassModule name classes mod` helper.

Rationale: the downstream convention is "everything flows through
config/options, never through function calls." A helper would force
consumer sites to `import (inputs.nix-lib.lib.mkCrossClassModule)`
into each option file - a wiring seam we do not want. Contributing to
an option costs one attribute at the consumer, zero import lines, and
composes with the module system's ordinary merge semantics.

Consequence: the primitive is a *module*, not a function. Its
implementation is one file with `options` and `config` sections. Users
learn the option name and the shape of its value; they never learn a
helper API.

### D2. Aggregator emits per-class entries via `mkMerge`

Chosen shape:

```nix
config.flake.modules = lib.mkMerge (
  lib.mapAttrsToList (name: def:
    lib.genAttrs def.classes (class: {
      ${name} = {
        imports =
          [ def.module ]
          ++ map
               (n: config.flake.modules.${class}.${n})
               (lib.filter
                 (n:
                   let cm = config.flake.crossClassModules.${n} or null;
                   in cm == null || builtins.elem class cm.classes
                 )
                 def.includes);
      };
    })
  ) config.flake.crossClassModules
);
```

Rationale:

- **`mkMerge` of per-class lists** rather than a single flat attrset
  assignment: preserves flake-parts' expected merge semantics with any
  hand-written `flake.modules.<class>.<name>` sites that coexist in the
  same repo. If both this primitive and a hand-written module target
  the same `flake.modules.nixos.foo` path, the module system merges
  them (imports concatenate). No override, no conflict.
- **`genAttrs def.classes`** iterates only the declared classes for
  this entry. An entry with `classes = [ nixos systemManager ]`
  contributes to two class-cells and stays absent from the third.
- **The `includes` filter is per-class**: for each included name `n`,
  the aggregator looks up `config.flake.crossClassModules.${n}` and
  includes it in this class-cell only if the target class is in
  `n.classes`. If `n` is not in `crossClassModules` at all (a
  hand-written module), it falls back to unconditional inclusion via
  `config.flake.modules.${class}.${n}` - the interop path for the
  tier-rollout transition period at nix-oci.

### D3. Option types

- `classes`: `listOf str`. Free-form: nix-lib does not enforce which
  class names are "real." That is a downstream concern (flake-parts
  itself rejects unknown class registrations at module-system eval
  time via its own `flake.modules` type checker, if
  `flakeModules.modules` is imported).
- `module`: `deferredModule`. Same shape as flake-parts' own
  `flake.modules.<class>.<name>` values. Callers write it identically
  to how they would write today.
- `includes`: `listOf str`, default `[]`. Names of other
  `crossClassModules` entries (or, transitionally, hand-written
  `flake.modules.<class>.<name>` names) whose class-cell should be
  merged into this entry's class-cell.

No `defaultFunctor`, no `provides`, no cycle detection. Kept minimal
on purpose - Tier A at the driver (nix-oci) does not need those, and
adding them now would ship untested surface.

### D4. Interop fallback for hand-written modules

Rationale: at the driver (nix-oci), the migration is tiered. During
Tier A, the composer's `includes` list mixes:
- names of entries migrated to `crossClassModules` (e.g. `nix-oci-enable`), and
- names of entries still hand-written to `flake.modules.<class>.<name>`
  (e.g. `soci-snapshotter`, `nix-oci-load-services`).

The aggregator handles both via the `cm == null || ...` clause: if
the name is not in `crossClassModules`, include it unconditionally
(the module-tree lookup will find or fail exactly as today).

Consequence: once Tier B/C migrate every cross-class registration, the
fallback branch is dead code. Not removed here - the branch has
non-zero value for any future consumer who adopts the primitive
gradually.

### D5. Tests as scenarios, not as ad-hoc `.tests.nix`

nix-lib runs tests through the `tests/scenarios/` convention (see
`internal-dendritic-import-tree` §Tasks). This change follows suit:
four small scenarios under `tests/scenarios/cross-class-modules/`,
each a self-contained flake-parts eval that asserts one property from
the What Changes section.

Rationale: matches existing conventions; auto-discovered; contributes
a `checks.<system>.crossClassModulesTests` derivation without any
manual registration.

## Risks / Trade-offs

- **Consumer confusion between `crossClassModules` and `flake.modules`**
  → mitigation: README + top-of-file docstring explain the seam. Both
  coexist. `crossClassModules` is optional sugar.
- **Deferred-module type quirks** → mitigation: covered by test
  scenarios; failure at eval time surfaces immediately.
- **Downstream driver assumes semantics not asserted by tests** →
  mitigation: nix-oci change references specific scenarios by name in
  its own design.md, so drift between assumption and assertion is
  surfaced at code review.

## Open Questions

None.
