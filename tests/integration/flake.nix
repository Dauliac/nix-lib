{
  description = "nlib integration test - flake + nixos + perSystem libs + JUnit";

  inputs.get-flake.url = "github:ursi/get-flake";

  outputs =
    inputs:
    let
      nlib = inputs.get-flake ../../.;
      inherit (nlib.inputs) nixpkgs;
      inherit (nlib.inputs) nix-unit;
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
      # Define at nlib.lib.<name>, output at lib.flake.<name>
      nlib.lib.double = {
        type = nixpkgs.lib.types.functionTo nixpkgs.lib.types.int;
        fn = x: x * 2;
        description = "Double a number";
        tests."doubles 5" = {
          args.x = 5;
          expected = 10;
        };
      };

      # Nested namespace example: nlib.lib.math.square
      # Available at lib.flake.math.square
      nlib.lib.math.square = {
        type = nixpkgs.lib.types.functionTo nixpkgs.lib.types.int;
        fn = x: x * x;
        description = "Square a number";
        tests."squares 4" = {
          args.x = 4;
          expected = 16;
        };
      };

      nlib.lib.math.cube = {
        type = nixpkgs.lib.types.functionTo nixpkgs.lib.types.int;
        fn = x: x * x * x;
        description = "Cube a number";
        tests."cubes 3" = {
          args.x = 3;
          expected = 27;
        };
      };

      # perSystem follows flake-parts conventions
      perSystem =
        { lib, system, ... }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # Per-system libs (depend on pkgs)
          # Define at nlib.lib.<name>, output at lib.<name>
          nlib.lib.writeGreeting = {
            type = lib.types.functionTo lib.types.package;
            fn = name: pkgs.writeText "greeting-${name}" "Hello, ${name}!";
            description = "Write a greeting file for a person";
            tests."writes greeting for Alice" = {
              args.name = "Alice";
              expected = "greeting-Alice";
            };
          };

          # Development shell with nix-unit
          devShells.default = pkgs.mkShell {
            packages = [ nix-unit.packages.${system}.default ];
            shellHook = ''
              echo "Run tests: nix-unit --flake .#tests.lib"
            '';
          };
        };

      flake.nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nlib.nixosModules.default
          {
            nlib.enable = true;

            # NixOS libs - define at nlib.lib.<name>, output at lib.<name>
            nlib.lib.triple = {
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
