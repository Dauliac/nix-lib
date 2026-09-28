# Full nix-lib module: all option modules auto-discovered.
#
# Discovery uses the vendored import-tree at ./_lib/import-tree/. Every
# .nix file under ./ is imported except paths containing a `/_`
# segment (private helpers, factories, types, and internal libraries).
#
# Adding a new option module: drop a .nix file anywhere under
# modules/nix-lib/ whose name does not start with `_` and whose path
# does not traverse a `_`-prefixed directory. It becomes a live
# flake-parts module without touching any index file.
#
# Pure variant (no pkgs, no docs, no per-system): see ./_pure.nix.
let
  importTree = import ./_lib/import-tree;
in
{ ... }:
{
  imports = [ (importTree ./.) ];
}
