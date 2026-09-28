# Pure nix-lib module: zero pkgs dependency.
#
# Same discovery as ./_default.nix, minus docs and per-system libs.
# Excluded (regex on file path):
#   - `/docs/`         : documentation package needs pkgs.
#   - `/lib/perSystem.nix` : per-system lib option needs pkgs.
#
# Adding a new option module: same rule as ./_default.nix. If the new
# module depends on pkgs, place it under `docs/` or a new directory
# added to the exclusion list below.
#
# Usage:
#   imports = [ nix-lib.flakeModules.pure ];
let
  importTree = import ./_lib/import-tree;
in
{ ... }:
{
  imports = [
    (importTree.filterNot (
      p: builtins.match ".*/docs/.*" p != null || builtins.match ".*/lib/perSystem\\.nix" p != null
    ) ./.)
  ];
}
