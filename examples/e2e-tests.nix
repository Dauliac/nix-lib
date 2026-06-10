# Example: Running the E2E test suite
#
# nix-lib provides a scenario-based E2E test runner that exercises all
# supported backends and integration modes.
#
# Run all scenarios:
#   nix run .#test-e2e
#
# Run a single scenario:
#   cd tests/scenarios/nix-unit
#   nix run .#test
#
# ============================================================
# Test scenarios (in tests/scenarios/):
# ============================================================
#
#   nix-unit            Tests using the nix-unit backend (default)
#   nix-tests           Tests using nix-tests backend with devour-flake
#   standalone          Standalone test setup (no flake-parts)
#   mkFlake-flake-parts mkFlake with flake-parts integration
#   mkFlake-standalone  mkFlake without flake-parts
#   linter-fail         Verifies linter correctly rejects invalid code
#
# ============================================================
# Test layers:
# ============================================================
#
#   Unit tests      nix-lib.lib.*.tests       Function behavior (inline)
#   BDD tests       tests/bdd/*.nix           Structure validation
#   perSystem tests perSystem.nix-unit.tests   System-specific checks
#   E2E scenarios   tests/scenarios/*/         Full integration per backend
#
# ============================================================
# Adding a new test scenario:
# ============================================================
#
#   1. Create a directory: tests/scenarios/my-scenario/
#   2. Add a flake.nix that defines `apps.test`
#   3. Import your lib modules and BDD test modules
#   4. The test runner will pick it up if added to modules/e2e-tests.nix
#
# ============================================================
# Example scenario flake.nix structure:
# ============================================================
#
#   {
#     inputs = {
#       nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
#       nix-lib.url = "github:Dauliac/nix-lib";
#       nix-unit.url = "github:nix-community/nix-unit";
#     };
#
#     outputs = inputs:
#       inputs.nix-lib.inputs.flake-parts.lib.mkFlake { inherit inputs; } {
#         imports = [ inputs.nix-lib.flakeModules.default ];
#
#         systems = [ "x86_64-linux" ];
#
#         # Define libs with tests
#         nix-lib.lib.myFunc = {
#           fn = x: x + 1;
#           description = "Increment";
#           tests."increments" = { args.x = 1; expected = 2; };
#         };
#
#         # Test app runs nix-unit against flake.tests
#         perSystem = { pkgs, ... }: {
#           apps.test = {
#             type = "app";
#             program = "${pkgs.writeShellScript "test" ''
#               ${pkgs.nix-unit}/bin/nix-unit --flake .#tests
#             ''}";
#           };
#         };
#       };
#   }
#
"See the comments above for usage examples. This file is documentation only."
