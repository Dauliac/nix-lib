# Example: Generating API documentation from lib definitions
#
# nix-lib can generate a markdown API reference (docs.md) from all your
# lib metadata: types, descriptions, arguments, test cases, and even
# function bodies (via tree-sitter).
#
# Build:  nix build .#nix-lib-docs
# View:   cat result/docs.md
#
# Usage in flake.nix:
#
#   {
#     inputs = {
#       nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
#       flake-parts.url = "github:hercules-ci/flake-parts";
#       nix-lib.url = "github:Dauliac/nix-lib";
#     };
#
#     outputs = inputs:
#       inputs.nix-lib.inputs.flake-parts.lib.mkFlake { inherit inputs; } {
#         imports = [ inputs.nix-lib.flakeModules.default ];
#
#         systems = [ "x86_64-linux" "aarch64-linux" ];
#
#         # Define libs (these will appear in the generated docs)
#         nix-lib.lib.double = {
#           type = lib.types.functionTo lib.types.int;
#           fn = x: x * 2;
#           description = "Double a number";
#           file = "libs/math.nix";
#           example = "config.lib.flake.double 5  # => 10";
#           tests."doubles 5" = { args.x = 5; expected = 10; };
#         };
#
#         # Configure documentation generation
#         perSystem = { ... }: {
#           nix-lib.docs = {
#             # Set to `self` to enable tree-sitter fn body extraction.
#             # The generated docs will include collapsible implementation
#             # bodies for each function.
#             src = self;
#
#             # Include a clickable function index at the top of docs.md
#             showIndex = true;
#
#             # Include the "nix-lib API Reference" title and total lib count
#             showTitle = true;
#
#             # Export as `packages.nix-lib-docs` so you can `nix build .#nix-lib-docs`
#             # Set to false if you only want to use the package programmatically.
#             enableOutput = true;
#           };
#         };
#       };
#   }
#
# ============================================================
# Generated docs.md includes (for each lib):
# ============================================================
#
#   - Function arguments:   { a, b, c ? default }  or  x → y → z
#   - Type signature:       functionTo int
#   - Description:          from the lib definition
#   - Source file link:     clickable link to source
#   - Implementation body:  collapsible <details> (requires src = self)
#   - Test case table:      collapsible table with Input / Expected columns
#
# ============================================================
# Namespace prefixes in generated docs:
# ============================================================
#
#   Flake-level libs:       flake.<name>
#   NixOS libs:             nixos.<name>
#   home-manager libs:      home.<name>
#   nix-darwin libs:        darwin.<name>
#   nixvim libs:            vim.<name>
#   system-manager libs:    system.<name>
#   wrapper-modules libs:   wrappers.<name>
#   perSystem libs:         <name>  (no prefix)
#
# ============================================================
# Without tree-sitter (src = null, the default):
# ============================================================
#
#   Docs are generated in pure Nix. Faster builds, but no
#   implementation body sections. Everything else still works.
#
"See the comments above for usage examples. This file is documentation only."
