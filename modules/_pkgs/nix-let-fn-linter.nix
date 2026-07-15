# Nix Let-In Function Linter package
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      linter = pkgs.rustPlatform.buildRustPackage {
        pname = "nix-let-fn-linter";
        version = "0.1.0";
        src = ../../tools/nix-let-fn-linter;
        cargoLock = {
          lockFile = ../../tools/nix-let-fn-linter/Cargo.lock;
        };
        meta = {
          description = "A linter that detects function definitions in Nix let-in blocks";
          homepage = "https://github.com/Dauliac/nlib";
          license = pkgs.lib.licenses.mit;
          mainProgram = "nix-let-fn-linter";
        };
      };
    in
    {
      packages.nix-let-fn-linter = linter;

      apps.nix-let-fn-linter = {
        type = "app";
        program = "${linter}/bin/nix-let-fn-linter";
      };
    };
}
