# Capability: `flake-modules`

Cross-class module registration for flake-parts consumers. Provides a
single declarative option that fans a shared module body out to
multiple `flake.modules.<class>` keys, replacing hand-repeated
per-class registrations.

## ADDED Requirements

### Requirement: `flake.crossClassModules` option

The framework SHALL expose `flake.crossClassModules` as an
`attrsOf submodule` where each entry declares:

- `classes : listOf str` , the flake-parts module classes the body
  registers against (e.g. `[ "nixos" "homeManager" "systemManager" ]`).
- `module : deferredModule` , the module body registered against each
  class in `classes`.
- `includes : listOf str` , optional. Names of other entries whose
  bodies are included, filtered per-class by each included entry's
  own `classes`.

#### Scenario: symmetric registration

- **GIVEN** a consumer sets
  `flake.crossClassModules.foo = { classes = [ "nixos" "homeManager" "systemManager" ]; module = mod; }`
- **WHEN** the flake is evaluated
- **THEN** `flake.modules.nixos.foo`, `flake.modules.homeManager.foo`,
  and `flake.modules.systemManager.foo` all resolve to `mod`.

#### Scenario: asymmetric registration

- **GIVEN** a consumer sets
  `flake.crossClassModules.bar = { classes = [ "nixos" "systemManager" ]; module = mod; }`
- **WHEN** the flake is evaluated
- **THEN** `flake.modules.nixos.bar` and
  `flake.modules.systemManager.bar` resolve to `mod`, and
  `flake.modules.homeManager ? bar` is `false`.

### Requirement: `includes` composition

When an entry declares `includes = [ "subA" "subB" ]`, its emitted
`flake.modules.<class>.<name>` for each class in the composer's own
`classes` SHALL be a list of the composer's `module` plus the included
entries' `module`s, filtered so that each included entry only
contributes to classes it declared in its own `classes` field.

#### Scenario: per-class filter of included entries

- **GIVEN**
  `flake.crossClassModules.subA = { classes = [ "nixos" "homeManager" ]; module = modA; }`
  and
  `flake.crossClassModules.subB = { classes = [ "nixos" ]; module = modB; }`
  and
  `flake.crossClassModules.composer = { classes = [ "nixos" "homeManager" ]; module = modC; includes = [ "subA" "subB" ]; }`
- **WHEN** the flake is evaluated
- **THEN** `flake.modules.nixos.composer` contains `modC`, `modA`, and
  `modB`, and `flake.modules.homeManager.composer` contains `modC` and
  `modA` (not `modB`, since `subB` did not declare `homeManager`).

### Requirement: fallback lookup for `includes`

When an `includes` name is not present in `flake.crossClassModules`,
the aggregator SHALL treat it as an existing hand-written
`flake.modules.<class>.<name>` reference and include it
unconditionally per class. This lets consumers migrate incrementally.

#### Scenario: `includes` names a hand-written module

- **GIVEN**
  `flake.modules.nixos.legacy = legacyMod`
  and no `flake.crossClassModules.legacy` entry, and
  `flake.crossClassModules.composer = { classes = [ "nixos" ]; module = modC; includes = [ "legacy" ]; }`
- **WHEN** the flake is evaluated
- **THEN** `flake.modules.nixos.composer` includes both `modC` and
  `legacyMod`.

### Requirement: opt-in, no breaking change

Consumers that never declare `flake.crossClassModules` SHALL see no
behavioural change. Existing hand-written `flake.modules.<class>.<name>`
sites continue to work unchanged.

#### Scenario: consumer without crossClassModules

- **GIVEN** a consumer flake that imports
  `nix-lib.flakeModules.default` and defines no
  `flake.crossClassModules` entries
- **WHEN** the flake is evaluated
- **THEN** `flake.modules` reflects exactly what was written by hand,
  with no injected keys.
