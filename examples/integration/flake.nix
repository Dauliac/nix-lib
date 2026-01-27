{
  description = "nlib integration test - flake + nixos + perSystem libs + JUnit";

  inputs.get-flake.url = "github:ursi/get-flake";

  outputs =
    inputs:
    let
      nlib = inputs.get-flake ../../.;
      nixpkgs = nlib.inputs.nixpkgs;
      nix-unit = nlib.inputs.nix-unit;
    in
    nlib.inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [ nlib.flakeModules.default ];

      # Testing configuration with JUnit reporter
      nlib.testing = {
        backend = "nix-unit";
        reporter = "junit";
        outputPath = "test-results.xml";
      };

      # Flake-level libs (pure, no pkgs dependency)
      # Direct config.lib.flake.<name> API
      lib.flake.double = {
        type = nixpkgs.lib.types.functionTo nixpkgs.lib.types.int;
        fn = x: x * 2;
        description = "Double a number";
        tests."doubles 5" = {
          args.x = 5;
          expected = 10;
        };
      };

      # perSystem follows flake-parts conventions
      perSystem =
        {
          lib,
          system,
          config,
          _nlibPerSystem,
          _nlibMkTestRunner,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # Provide pkgs for flake-parts
          _module.args.pkgs = pkgs;

          # Per-system libs (depend on pkgs) - direct config.lib.<name> API
          lib.writeGreeting = {
            type = lib.types.functionTo lib.types.package;
            fn = name: pkgs.writeText "greeting-${name}" "Hello, ${name}!";
            description = "Write a greeting file for a person";
            tests."writes greeting for Alice" = {
              args.name = "Alice";
              expected = "greeting-Alice";
            };
          };

          # Expose perSystem libs
          legacyPackages._nlib = _nlibPerSystem;

          # Test runner with JUnit support
          packages.nlib-test = _nlibMkTestRunner nix-unit.packages.${system}.default;

          # Development shell with nix-unit
          devShells.default = pkgs.mkShell {
            packages = [
              nix-unit.packages.${system}.default
            ];
            shellHook = ''
              echo "Run tests: nix-unit --flake .#tests.lib"
              echo "Or use: nix run .#nlib-test"
            '';
          };
        };

      flake.nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nlib.nixosModules.default
          {
            nlib.enable = true;

            # NixOS libs - direct config.lib.<name> API
            lib.triple = {
              type = nixpkgs.lib.types.functionTo nixpkgs.lib.types.int;
              fn = x: x * 3;
              description = "Triple a number";
              tests."triples 4" = {
                args.x = 4;
                expected = 12;
              };
            };

            fileSystems."/".device = "/dev/null";
            boot.loader.grub.device = "/dev/null";
            system.stateVersion = "24.05";
          }
        ];
      };
    };
}
