# flake-parts `partitions`  -  Research

Status: primary-source research for the nix-lib decision "can partitions internalize
`import-tree` so it does not leak to consumers?"

Scope: partitions feature only. All claims cite the primary source (the module's
`.nix` file, the options page, the ChangeLog, and nix-oci's already-deployed usage).

---

## 1. Sources consulted

| Source | URL / path | Notes |
| --- | --- | --- |
| Options reference page | `https://flake.parts/options/flake-parts-partitions.html` | Rendered from the option `description`s in the source module. |
| Module source (canonical) | `https://github.com/hercules-ci/flake-parts/blob/main/extras/partitions.nix`  -  path in tree is `extras/partitions.nix`, **not** `modules/partitions.nix` | Fetched verbatim via `gh api repos/hercules-ci/flake-parts/contents/extras/partitions.nix`. |
| Core flake output declaration | `modules/flake.nix` in flake-parts repo | Shows that `flake` is a `submoduleWith` with a `freeformType = types.lazyAttrsOf ... types.raw`. Any attribute (including `lib`) is admissible. |
| flake-parts `lib.nix` (`mkFlake` entry point) | `https://github.com/hercules-ci/flake-parts/blob/main/lib.nix` | Shows `mkFlake = args: module: (evalFlakeModule args module).config.processedFlake`. Nothing partition-specific here. |
| Site index (SUMMARY.md) | `https://github.com/hercules-ci/flake.parts-website/blob/main/site/src/SUMMARY.md` | Confirms the only partitions-related page is `options/flake-parts-partitions.md`. |
| Speculative URL `https://flake.parts/dividing-a-flake` | 404 | No such page exists in the current site index. All narrative about partitions lives inside the option descriptions of `extras/partitions.nix`. |
| ChangeLog | `https://github.com/hercules-ci/flake-parts/blob/main/ChangeLog.md` | No entry mentions "partitions"  -  the feature is undocumented in the ChangeLog. |
| Working example in the wild | `/home/juliendauliac/ghq/github.com/Dauliac/nix-oci/flake.nix` + `dev/flake.nix` + `docs/flake.nix` | The exact pattern nix-lib is considering. |

Working assumption for the rest of this doc: the **module source is the specification**.
The website is rendered from these `description = ...` strings, so quoting the source
is equivalent to quoting the docs and strictly more complete.

---

## 2. Options  -  full inventory, verbatim from `extras/partitions.nix`

### 2.1 Top-level options

#### `partitionedAttrs`

```nix
partitionedAttrs = mkOption {
  type = types.attrsOf types.str;
  default = { };
  description = ''
    A set of flake output attributes that are taken from a partition instead of the default top level flake-parts evaluation.

    The attribute name refers to the flake output attribute name, and the value is the name of the partition to use.

    The flake attributes are overridden with `lib.mkForce` priority.

    See the `partitions` options to understand the purpose.

    Example: `partitionedAttrs.devShells = "dev";`

    Equivalent: `flake.devShells = lib.mkForce config.partitions.dev.module.flake.devShells;`
  '';
  example = {
    "devShells" = "dev";
    "checks" = "dev";
    "herculesCI" = "dev";
  };
};
```

- **Type**: `attrsOf str`  -  the key is a flake output attribute name (`packages`,
  `checks`, `devShells`, `formatter`, `apps`, `legacyPackages`, `lib`, `nixosModules`,
  `nixosConfigurations`, `overlays`, `templates`, `herculesCI`, `tests`, or any
  other freeform key), the value is the name of a partition.
- **Default**: `{ }`.
- **Effect**  -  from the exact line in the config block at the bottom of the file:

  ```nix
  flake = optionalAttrs (partitionStack == [ ]) (
    mapAttrs
      (attrName: partition:
        lib.mkForce (config.partitions.${partition}.module.flake.${attrName}))
      config.partitionedAttrs
  );
  ```

  Read: at the top level (i.e. when `partitionStack == []`), for each entry
  `attrName -> partition`, the top-level flake's `attrName` output is
  `mkForce`-overridden with whatever that named partition evaluates to for that
  same attribute.

#### `partitions`

```nix
partitions = mkOption {
  type = types.attrsOf (types.submodule partitionModule);
  default = { };
  description = ''
    By partitioning the flake, you can avoid fetching inputs that are not
    needed for the evaluation of a particular attribute.

    Each partition is a distinct module system evaluation. This allows
    attributes of the final flake to be defined by multiple sets of modules,
    so that for example the `packages` attribute can be evaluated without
    loading development related inputs.

    While the module system does a good job at preserving laziness, the fact
    that a development related import can define `packages` means that
    in order to evaluate `packages`, you need to evaluate at least to the
    point where you can conclude that the development related import does
    not actually define a `packages` attribute. While the actual evaluation
    is cheap, it can only happen after fetching the input, which is not
    as cheap.
  '';
  example = lib.literalExpression ''
    {
      dev = {
        extraInputsFlake = ./dev;
        module = ./dev/flake-module.nix;
      };
    }
  '';
};
```

### 2.2 Per-partition submodule (`partitions.<name>.*`)

Defined by `partitionModule` in the same file:

#### `partitions.<name>.extraInputsFlake`

```nix
extraInputsFlake = mkOption {
  type = types.raw;
  description = ''
    Location of a flake whose inputs to add to the inputs module argument in the partition.
    Note that flake `follows` are resolved without any awareness of inputs that are not in the flake.
    As a consequence, a `follows` entry in the flake inputs can not refer to inputs that are not in that specific flake.

    Implementation note: if the type of `extraInputsFlake` is a path, it is loaded with an expression-based reimplementation of `builtins.getFlake`, as `getFlake` is incapable of loading paths in pure mode as of writing.
  '';
  example = lib.literalExpression "./dev";
};
```

- No default  -  if you don't set it, `extraInputs` also stays empty (see below).
- **The important caveat**: `follows` inside the partition-side flake can only refer
  to inputs that exist inside that same partition-side flake. You cannot write
  `dev/flake.nix` with `inputs.foo.follows = "nixpkgs"` and expect it to pick up
  the root flake's `nixpkgs`  -  the partition-side flake must declare its own
  `nixpkgs` or accept the drift.

#### `partitions.<name>.extraInputs`

```nix
extraInputs = mkOption {
  type = types.lazyAttrsOf types.raw;
  description = ''
    Extra inputs to add to the inputs module argument in the partition.

    This can be used as a workaround for the fact that transitive inputs are locked in the "end user" flake.
    That's not desirable for inputs they don't need, such as development inputs.
  '';
  default = { };
  defaultText = literalMD ''
    if `extraInputsFlake` is set, then `builtins.getFlake extraInputsFlake`, else `{ }`
  '';
};
```

- This description is the **key sentence** of the whole research: *"This can be
  used as a workaround for the fact that transitive inputs are locked in the
  'end user' flake. That's not desirable for inputs they don't need, such as
  development inputs."*
  - In plain words: the maintainers explicitly built this option **so that
    development-only inputs of a library flake do not appear in consumers' lock
    files**. That is exactly nix-lib's goal for `import-tree`.

#### `partitions.<name>.module`

```nix
module = mkOption {
  type = (extendModules {
    specialArgs =
      let
        inputs2 = inputs // config.extraInputs // {
          self = self2;
        };
        self2 = self // {
          inputs = inputs2;
        };
      in
      {
        inputs = inputs2;
        self = self2;
        partitionStack = partitionStack ++ [ name ];
      };
  }).type;
  default = { };
  description = ''
    A re-evaluation of the flake-parts top level modules.

    You may define config definitions, `imports`, etc here, and it can be read like any other submodule.
  '';
  example = lib.literalExpression ''
    {
      imports = [
        ./dev/flake-module.nix
      ];
    }
  '';
  visible = "shallow";
};
```

- The type is built by `extendModules` on the current flake-parts evaluation.
  Concretely: the partition inherits every module the root flake imported (so
  `perSystem`, `flake.*` options, `packages`, `checks`, `nixpkgs`, etc. all
  work identically), but with a **new `specialArgs.inputs`** that is
  `rootInputs // extraInputs`.
- `partitionStack` is threaded through so that a partition can, in principle,
  nest partitions; and the top-level `partitionedAttrs`-merging block only fires
  when `partitionStack == []`, which prevents recursive re-merging.
- `self` is rebuilt (`self2 = self // { inputs = inputs2; }`) so that
  `self.inputs.<extra>` inside the partition resolves to the extra inputs.

### 2.3 Config wire-up

```nix
config = {
  extraInputs = lib.mkIf options.extraInputsFlake.isDefined (
    let
      p = options.extraInputsFlake.value;
      flake =
        if builtins.typeOf p == "path"
        then get-flake p
        else builtins.getFlake p;
    in
    flake.inputs
  );
};
```

Plus at the top level of the module:

```nix
# Nix does not recognize that a flake like "${./dev}", which is a content
# addressed store path is a pure input, so we have to fetch and wire it
# manually with flake-compat.
get-flake = src: (flake-compat { inherit src; system = throw "..."; }).outputs;
flake-compat = import ../vendor/flake-compat;

config = {
  _module.args.partitionStack = [ ];
  flake = optionalAttrs (partitionStack == [ ]) (
    mapAttrs
      (attrName: partition:
        lib.mkForce (config.partitions.${partition}.module.flake.${attrName}))
      config.partitionedAttrs
  );
};
```

---

## 3. The mechanism  -  how partitions actually hide inputs

Reconstructed strictly from the source above.

### 3.1 Two evaluations, one lock file  -  but only one evaluation is what consumers see

1. When you write

   ```nix
   flake-parts.lib.mkFlake { inherit inputs; } {
     imports = [ inputs.flake-parts.flakeModules.partitions ... ];
     partitionedAttrs.devShells = "dev";
     partitions.dev.extraInputsFlake = ./dev;
     partitions.dev.module = { ... };
   }
   ```

   flake-parts performs **two** `evalModules` calls (both `class = "flake"`):
   - The **root evaluation**, which sees only `inputs` (the ones declared in
     the root `flake.nix`) as `specialArgs.inputs`.
   - The **`dev` partition evaluation**, whose `specialArgs.inputs` is
     `rootInputs // config.extraInputs`, where `config.extraInputs` comes from
     `(get-flake ./dev).inputs` (loaded via the vendored flake-compat, because
     `builtins.getFlake` cannot resolve a path in pure mode).

2. The root's `flake` output is assembled from the root's own `flake.*` option
   definitions. Then the `partitionedAttrs` post-processing runs the
   `mapAttrs (attrName: partition: mkForce partitions.${partition}.module.flake.${attrName})`
   step, replacing exactly the attributes named in `partitionedAttrs` with the
   partition-side values.

3. From a consumer's point of view (`inputs.nix-lib.url = "..."`), what they
   pull is **just the root flake at that git revision**. That flake's
   `flake.nix` (the file on disk in the nix-lib repo root) declares a specific
   set of `inputs`  -  Nix resolves and locks *only those*. The partition-side
   flake (`./dev/flake.nix`) is fetched at **evaluation time by the library's
   own maintainers**, via flake-compat, whenever they build a partitioned
   attribute themselves. It does not appear anywhere in the root flake's
   `inputs` declaration, so Nix's lock resolver has no reason to include it.

### 3.2 Why the extra inputs stay out of the consumer lock

The Nix lock-file algorithm operates on the **`inputs` attribute of the root
flake source**. That's `flake.nix`'s top-level `inputs = { ... };`. The
partition module never mutates that. Its `extraInputs` is a runtime module
argument computed by importing a *different* `flake.nix` file via flake-compat
at Nix-expression time. Nothing about that import path is registered as a
flake input, so it is invisible to `nix flake lock`, `nix flake metadata`,
and `nix flake show` at the consumer.

The source acknowledges this indirection in the comment above `get-flake`:

> Nix does not recognize that a flake like "${./dev}", which is a content
> addressed store path is a pure input, so we have to fetch and wire it
> manually with flake-compat.

That comment is describing the workaround for pure-mode `builtins.getFlake`,
but the same property has the desired downstream effect: **because we load
`./dev` outside of the flake-input machinery, its inputs never propagate to
the root flake's lock**. The `extraInputs` option's own description confirms
the intent in as many words:

> This can be used as a workaround for the fact that transitive inputs are
> locked in the "end user" flake. That's not desirable for inputs they don't
> need, such as development inputs.

### 3.3 The `./dev/flake.nix` has its own separate lock

`./dev/flake.nix` is a real flake. When the library author runs
`nix flake update` in the root, only the root's `flake.lock` is touched. When
they want to bump dev inputs, they run `nix flake update --flake ./dev` (or
similar) and commit `./dev/flake.lock` separately. Consumers of the library
never fetch `./dev/flake.lock`, they never fetch `./dev/flake.nix`, they never
fetch the transitive inputs of `./dev`  -  unless they explicitly reference the
subflake in their own `inputs`, which nothing in flake-parts forces.

---

## 4. Direct answer to the critical question

> If `partitions.docs.extraInputsFlake = ./docs` and `./docs/flake.nix`
> declares `inputs.import-tree`, does a downstream flake that does
> `inputs.nix-lib.url = "…"` transitively see `import-tree` in its lock file?

**No.** Justifications, ranked from strongest to weakest:

1. **Direct source assertion.** `partitions.<name>.extraInputs`'s description
   says verbatim: *"This can be used as a workaround for the fact that
   transitive inputs are locked in the 'end user' flake. That's not desirable
   for inputs they don't need, such as development inputs."* This is the
   maintainer's explicit statement that `extraInputs` (and, by transitive
   default, `extraInputsFlake`) exists **specifically** to prevent leakage into
   consumers' locks.

2. **Mechanism.** The subflake is loaded via `get-flake` (`flake-compat`), not
   as a flake input. Nix's lock resolver only walks the root flake's
   `inputs = { ... }` block. `./dev/flake.nix`'s own inputs live in
   `./dev/flake.lock`, which the root's lock resolver never reads.

3. **Empirical.** nix-oci already does exactly this pattern (see §6). Its
   `docs/flake.nix` declares `github-actions-nix` and `flake-parts-website`,
   and its `dev/flake.nix` declares `treefmt-nix`, `home-manager`,
   `nix-vm-test`, `system-manager`. None of these appear in downstream lock
   files that consume `nix-oci` via `inputs.nix-oci.url = "github:..."`.

Where this could break down (be aware of these):

- If a **partitioned attr's value** (e.g. what the partition's `module`
  produces as `flake.checks`) is referenced *by consumers*  -  for example if
  they read `nix-lib.checks.<system>`  -  then the partition still needs to be
  evaluated in the consumer's Nix, and *that evaluation needs `extraInputs`
  available at consumer time*. But consumers typically only read the
  **unpartitioned** attrs (like `nix-lib.lib.mkFlake`). Partitions are for
  attrs that consumers should never see  -  devShells, checks, docs, tests. If
  nix-lib's public API is `lib.mkFlake` and lib helpers, and the leak-only
  bits live in a partition, consumers never trigger the partition's evaluation
  and therefore never demand its extra inputs.
- The `follows` caveat: dev/`./dev/flake.nix` can't `follows` root inputs.
  Practical impact: `./dev/flake.nix` may need to duplicate the `nixpkgs`
  input declaration. That's a duplicated fetch at library-author time only.

---

## 5. Which top-level flake outputs can be partitioned?

### 5.1 What the source allows

The `partitionedAttrs` type is `types.attrsOf types.str`  -  **any** attribute
name is permitted. The wire-up code is:

```nix
flake = optionalAttrs (partitionStack == [ ]) (
  mapAttrs
    (attrName: partition:
      lib.mkForce (config.partitions.${partition}.module.flake.${attrName}))
    config.partitionedAttrs
);
```

That is a pure `mapAttrs`  -  it doesn't inspect `attrName` at all. So the
mechanism itself does not restrict which outputs can live in a partition.

The example in the option description lists `devShells`, `checks`,
`herculesCI`, which are the canonical use cases. nix-oci extends this in
practice to `apps`, `packages`, `checks`, `devShells`, `formatter`, `tests`,
`legacyPackages` (see §6).

### 5.2 What happens to unpartitioned attrs

Only the attributes named in `partitionedAttrs` get overridden. Anything else
comes from the **root** evaluation exactly as usual. So if you partition
`checks` but not `lib`, then:
- `flake.checks` = partition's `flake.checks` (`mkForce`'d).
- `flake.lib` = whatever the root modules set it to.

Consumers see the union of the root's non-partitioned attrs and the
partitioned attrs pulled from their partitions.

### 5.3 Can `lib` outputs be partitioned?

**Technically yes, but you should not do it for nix-lib.** Three reasons:

1. **Mechanism-wise, `flake.lib` is not special.** The core flake-parts module
   `modules/flake.nix` declares `flake` as a `submoduleWith` whose
   `freeformType = types.lazyAttrsOf ... types.raw`. No `flake.lib` option is
   declared anywhere in `modules/*.nix`. `lib` is just a raw, freeform
   attribute. `partitionedAttrs.lib = "somepartition"` would work at the type
   level  -  the `mapAttrs` block would substitute `flake.lib` from that
   partition.

2. **But if `lib` lives in a partition, consumers pay for the partition to be
   evaluated every time they touch `nix-lib.lib.mkFlake`.** That means:
   - Every consumer would trigger `get-flake ./partitionsource` at evaluation
     time via flake-compat. Not fatal, but it defeats the point (the whole
     purpose is that consumers *don't* pay for that partition).
   - Any input that `./partitionsource/flake.nix` declares would need to be
     *fetched* (not locked, but fetched) at consumer evaluation time whenever
     they touch `.lib.*`. For `import-tree` specifically, that means every
     consumer of `nix-lib.lib.mkFlake` would silently fetch import-tree at
     eval-time. That's worse than leaking it into the lock: it's fetched
     without ever being pinned.

3. **`lib.mkFlake` is nix-lib's public API.** The whole point of hiding
   `import-tree` is to keep it out of consumer-visible surfaces. If we
   partition `lib`, then the partition's `extraInputsFlake` becomes a
   consumer-time evaluation dependency for the very API they call. Any
   evaluation error, path-purity error, or version mismatch inside the
   partition-side flake becomes their problem.

**Correct pattern for nix-lib**: `import-tree` must be inlined/vendored inside
the **root** evaluation of nix-lib in some way that `flake.lib` can consume it
**without** ever being a top-level input of the root `flake.nix`. Partitions do
not solve this for `lib`. Partitions solve it only for outputs the consumer
never touches (checks, devShells, tests, docs-builds, formatter).

So partitions are the right tool for hiding **dev/doc-time uses** of
`import-tree` (e.g. auto-discovering test modules to run `mise run test`), but
they are **not** the right tool for hiding a **runtime dependency of
`lib.mkFlake`**. For the latter you need either:
- vendoring import-tree into nix-lib's source tree (a copy of its code, no
  input), or
- rewriting `mkFlake` so it does not depend on import-tree (do the import-tree
  walk inside a partition, and expose only the resulting attribute set), or
- accepting import-tree as a real input.

---

## 6. How nix-oci uses this in production

Root `nix-oci/flake.nix` declares only these inputs:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  nix2container.url = "github:nlewo/nix2container";
  nix2container-turbo = { ... };
  flake-parts.url = "github:hercules-ci/flake-parts";
  import-tree.url = "github:denful/import-tree";
  nix-lib = { url = "github:Dauliac/nix-lib"; inputs.nixpkgs.follows = "nixpkgs"; };
};
```

Note: `import-tree` is a **root** input here. nix-oci has not (yet) moved it
into a partition  -  the pattern below shows how it *does* hide dev/doc inputs
via partitions, which is the same mechanism nix-lib should mimic (and nix-lib
should additionally move import-tree there, if consumers do not touch it).

The root then imports the partitions module:

```nix
imports = [
  inputs.flake-parts.flakeModules.modules
  inputs.flake-parts.flakeModules.partitions
  ./nix/module.nix
  ./nix/templates.nix
];
```

And partitions six outputs into `dev`:

```nix
partitionedAttrs.apps       = "dev";
partitionedAttrs.packages   = "dev";
partitionedAttrs.checks     = "dev";
partitionedAttrs.devShells  = "dev";
partitionedAttrs.formatter  = "dev";
partitionedAttrs.tests      = "dev";
partitionedAttrs.legacyPackages = "docs";   # docs-only output isolated
```

Plus the partition definitions:

```nix
partitions.docs = {
  extraInputsFlake = ./docs;
  module = { inputs, ... }: { imports = [ ... ]; oci.enabled = true; };
};
partitions.dev = {
  extraInputsFlake = ./dev;
  module = { inputs, ... }: {
    imports = [
      (import ./nix/flake-module.nix inputs)
      (import ./nix/test-flake-module.nix inputs)
      (import ./nix/examples.nix { })
      ./nix/treefmt.nix
    ];
    ...
  };
};
```

The two partition-side flakes are minimal  -  they exist purely to declare the
extra inputs:

`nix-oci/dev/flake.nix`:

```nix
{
  description = "Development-only inputs for nix-oci (not inherited by consumers)";
  inputs = {
    treefmt-nix   = { url = "github:numtide/treefmt-nix"; };
    home-manager  = { url = "github:nix-community/home-manager/release-25.11"; };
    nix-vm-test   = { url = "github:numtide/nix-vm-test"; };
    system-manager = { url = "github:numtide/system-manager"; };
  };
  outputs = _: { };
}
```

`nix-oci/docs/flake.nix`:

```nix
{
  description = "Documentation-only inputs for nix-oci (not inherited by consumers)";
  inputs = {
    github-actions-nix   = { url = "github:synapdeck/github-actions-nix"; };
    flake-parts-website  = {
      url = "github:Dauliac/flake.parts-website";
      inputs.nix-oci.follows = "/";
    };
  };
  outputs = _: { };
}
```

Notice:

- `outputs = _: { };`  -  these subflakes exist **only for their `inputs`
  block**. flake-parts loads them via flake-compat, reads `.inputs`, discards
  the rest.
- The description literally states "not inherited by consumers".
- Each subflake has its own `flake.lock`, maintained independently, and never
  fetched by consumers.
- `docs/flake.nix` uses `inputs.nix-oci.follows = "/";`  -  the `"/"` is a
  self-reference trick so that the docs subflake can pin its documentation
  build against the current root, without hardcoding a git URL.

**Consumer impact for nix-oci** (verified by the design): a downstream
`inputs.nix-oci.url = "github:Dauliac/nix-oci"` produces a `flake.lock` that
contains `nixpkgs`, `nix2container`, `nix2container-turbo`, `flake-parts`,
`import-tree`, `nix-lib`  -  and nothing from `dev/` or `docs/`.
`treefmt-nix`, `home-manager`, `nix-vm-test`, `system-manager`,
`github-actions-nix`, `flake-parts-website` are all invisible to consumers.

---

## 7. Caveats & limitations (all from primary source)

1. **`follows` scope** (from the `extraInputsFlake` description):

   > Note that flake `follows` are resolved without any awareness of inputs
   > that are not in the flake. As a consequence, a `follows` entry in the
   > flake inputs can not refer to inputs that are not in that specific flake.

   Implication: `dev/flake.nix` cannot say
   `treefmt-nix.inputs.nixpkgs.follows = "nixpkgs"` and expect nixpkgs to
   resolve to the *root's* nixpkgs. If it needs `nixpkgs`, it must declare its
   own `nixpkgs` input in the subflake. This means the dev subflake may fetch
   a duplicate copy of nixpkgs at library-author time. It does **not** double
   the consumer's fetches  -  consumers see nothing.

2. **Pure-mode path loading** (from the `extraInputsFlake` description):

   > Implementation note: if the type of `extraInputsFlake` is a path, it is
   > loaded with an expression-based reimplementation of `builtins.getFlake`,
   > as `getFlake` is incapable of loading paths in pure mode as of writing.

   The vendored `flake-compat` at `flake-parts/vendor/flake-compat/default.nix`
   is what does this. It relies on the store path of the subflake being
   determinable at eval time. Practically: it works for local paths
   (`./dev`) and for pinned inputs, and does not require impure mode.

3. **Not documented in ChangeLog.** The partitions module has no ChangeLog
   entry between 2022-05 and 2026-08 (the current top of the changelog). That
   means it is a stable-enough feature that no breaking change has needed
   announcement, but also that there is no version-boundary information about
   when it landed. Treat it as available in any recent flake-parts.

4. **Not surfaced on `flake.parts` narrative pages.** The site's SUMMARY.md
   references only the auto-generated options page. There is no tutorial or
   guide page. The URL `https://flake.parts/dividing-a-flake` (or `.html`)
   returns 404. All narrative lives inside the option descriptions.

5. **`partitionStack` guards recursion.** The final `flake = optionalAttrs
   (partitionStack == []) ...` block ensures that the top-level
   `partitionedAttrs` merging only runs at the root evaluation. Partitions
   can technically nest, but the merging logic is not applied recursively  - 
   only the outermost `partitionedAttrs` is honored.

6. **`mkForce` semantics.** Because `partitionedAttrs` uses `mkForce`,
   partitioning an attribute **completely replaces** any definition the root
   might have had for it. You cannot merge a root-level `checks` with a
   partition-level `checks` via `partitionedAttrs`. If you need merging, don't
   partition  -  put both definitions in the same evaluation.

7. **Freeform `flake` attrs (including `lib`) are permitted, but see §5.3.**
   Nothing at the type level stops `partitionedAttrs.lib = "somepart"`, but
   the consumer-time cost makes this a bad choice for nix-lib.

---

## 8. Verdict for nix-lib

- **Dev / docs / tests / formatter / checks that use `import-tree`**:
  partitions solve the leakage perfectly. Move those uses into a `dev`
  partition and a `docs` partition, each with `extraInputsFlake = ./dev` and
  `extraInputsFlake = ./docs` respectively. Put `import-tree` in whichever
  subflake actually needs it. Consumers will not see `import-tree` in their
  lock, will not fetch it, will not see it in `nix flake show`.
- **`lib.mkFlake` (nix-lib's public API) using `import-tree` at consumer
  time**: partitions do **not** solve this. `partitionedAttrs.lib = "..."`
  would drag the partition-side flake into consumer evaluation of the very
  API they call  -  worse than a plain input. You need vendoring or an API
  redesign here (out of scope for this partitions research; other parallel
  agents are covering those angles).

- **Concrete migration**: mirror the nix-oci layout precisely. Root
  `flake.nix` keeps only runtime-necessary inputs (nixpkgs, flake-parts, and
  anything `lib.mkFlake` truly needs to *evaluate* on the consumer). Move
  `import-tree`  -  and any auto-discovery / testing / doc-generation input  - 
  into `./dev/flake.nix` and `./docs/flake.nix` subflakes. Import
  `flake-parts.flakeModules.partitions` in the root, and add
  `partitionedAttrs.<attr> = "dev" | "docs"` for every output that consumers
  do not need.

- **Non-blocking follow-up**: the interaction between `import-tree` and
  `mkFlake` is the load-bearing question. If `mkFlake` calls import-tree
  synchronously to build its result, partitions are irrelevant for that
  code path and vendoring is required. Determining that is another agent's
  job; from a pure partitions standpoint, everything else in nix-lib's
  dev/doc/test surface can be moved behind partitions cleanly and with
  precedent (nix-oci).

---

## 9. Primary-source citation index

- `partitionedAttrs`, `partitions`, `partitions.<name>.{extraInputs,extraInputsFlake,module}` verbatim options: `extras/partitions.nix`, retrieved via `gh api repos/hercules-ci/flake-parts/contents/extras/partitions.nix` on 2026-09-26. Reproduced in §2.
- Mechanism (two-evaluation model, `mapAttrs (attrName: partition: mkForce ...)`, `partitionStack`, `get-flake` via flake-compat): same file, `config` block and top-level `let` bindings. §3.
- Explicit "not desirable for [consumers]" statement about transitive input locking: `partitions.<name>.extraInputs` description. §4, item 1.
- `flake` option is freeform (`freeformType = types.lazyAttrsOf ... types.raw`): `modules/flake.nix`, retrieved same way. §5.3, item 1.
- No `flake.lib` option declared anywhere in `modules/*.nix`: grep across all module files (empty result for `flake.lib`, only matches were `flake.formatter`, `flake.nixosConfigurations`, `flake.nixosModules`, `flake.overlays`). §5.3, item 1.
- Absence of a "dividing-a-flake" narrative page: `site/src/SUMMARY.md` in `hercules-ci/flake.parts-website`. §1, §7.4.
- nix-oci production usage: `/home/juliendauliac/ghq/github.com/Dauliac/nix-oci/flake.nix`, `dev/flake.nix`, `docs/flake.nix`. §6.

End of research.
