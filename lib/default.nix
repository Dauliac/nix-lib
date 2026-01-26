# nlib - Nix library utilities
#
# Exports:
#   - mkLibOption: Create mergeable lib option for options.lib
#   - mkLibOptionFromFileName: mkLibOption with name from filename (curried)
#   - wrapLibModule: Wrapper for import-tree to inject mkLibOptionFromFileName
#   - backends: Test backend adapters (nix-unit, nixt, nixtest, runTests)
#   - coverage: Coverage calculation utilities
{ lib }:
let
  mkLibOption = import ./mkLibOption.nix { inherit lib; };
  mkLibOptionFromFileName = import ./mkLibOptionFromFileName.nix { inherit lib; };

  # Wrapper for import-tree: injects mkLibOptionFromFileName with path context
  wrapLibModule =
    path: args:
    import path (
      args
      // {
        inherit lib mkLibOption;
        mkLibOptionFromFileName = mkLibOptionFromFileName path;
      }
    );
in
{
  inherit mkLibOption mkLibOptionFromFileName wrapLibModule;
  backends = import ./backends.nix { inherit lib; };
  coverage = import ./coverage.nix { inherit lib; };
}
