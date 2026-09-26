# Consumer-lock shape regression check.
#
# The core anti-goal of the internal-dendritic-import-tree change:
# nix-lib must not add any transitive input beyond flake-parts and
# nixpkgs-lib to a consumer's flake.lock. The most durable enforcement
# is to assert on nix-lib's own flake.lock at build time, since
# anything present there propagates to consumers.
#
# This check fails loudly if:
#   - A new input is added to nix-lib's flake.nix (breaks the
#     "only two consumer-visible inputs" contract).
#   - import-tree is re-introduced as a flake input (must stay
#     vendored under modules/nix-lib/_lib/import-tree/).
#   - A dev-partition input (nixpkgs, nix-unit, treefmt-nix,
#     nixtest, nix-tests, nixt, namaka, devour-flake, get-flake,
#     flake-file) escapes the dev partition and lands at root.
{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};

      # Ground-truth reads: the actual flake.lock this check runs
      # inside. Path is relative to the file that consumes this
      # module (modules/_dev/module.nix imports us), so ../../
      # resolves to the repo root.
      lock = builtins.fromJSON (builtins.readFile ../../flake.lock);

      rootInputs = builtins.attrNames (lock.nodes.root.inputs or { });
      allNodes = builtins.attrNames lock.nodes;
      nonRoot = builtins.filter (n: n != "root") allNodes;

      forbidden = [
        "import-tree"
        "nixpkgs"
        "nix-unit"
        "treefmt-nix"
        "nixtest"
        "nix-tests"
        "nixt"
        "namaka"
        "devour-flake"
        "get-flake"
        "flake-file"
      ];
      forbiddenPresent = builtins.filter (n: builtins.elem n allNodes) forbidden;

      expected = [
        "flake-parts"
        "nixpkgs-lib"
      ];
      sortedRoot = builtins.sort (a: b: a < b) rootInputs;
      sortedExpected = builtins.sort (a: b: a < b) expected;
      rootMatches = sortedRoot == sortedExpected;
    in
    {
      checks.consumer-lock-shape =
        assert (
          rootMatches
          || throw "nix-lib root inputs drifted from [flake-parts, nixpkgs-lib]. Got: ${builtins.toJSON sortedRoot}. See openspec/changes/internal-dendritic-import-tree/proposal.md for the contract."
        );
        assert (
          forbiddenPresent == [ ]
          || throw "Forbidden entries appeared in nix-lib flake.lock: ${builtins.toJSON forbiddenPresent}. These inputs must live under the dev partition (modules/_dev/flake.nix), not the root flake."
        );
        assert (
          builtins.length allNodes == 3
          || throw "nix-lib flake.lock now has ${toString (builtins.length allNodes)} nodes (expected 3: root, flake-parts, nixpkgs-lib). New consumer-visible input? Got: ${builtins.toJSON allNodes}."
        );
        pkgs.runCommand "consumer-lock-shape-check" { } ''
          echo "consumer-lock-shape: nix-lib root inputs match [flake-parts, nixpkgs-lib]."
          echo "consumer-lock-shape: no forbidden entries in flake.lock (${toString (builtins.length forbidden)} names checked)."
          echo "consumer-lock-shape: flake.lock node count is 3."
          echo "consumer-lock-shape: import-tree stays vendored, not an input."
          touch $out
        '';
    };
}
