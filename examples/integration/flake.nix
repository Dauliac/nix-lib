{
  description = "nlib integration test - flake + nixos libs";

  inputs.get-flake.url = "github:ursi/get-flake";

  outputs =
    inputs:
    let
      nlib = inputs.get-flake ../../.;
      nixpkgs = nlib.inputs.nixpkgs;
    in
    nlib.inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [ nlib.flakeModules.default ];

      # Flake-level libs
      nlib.perLib =
        { lib, mkLibOption, ... }:
        {
          options.lib = mkLibOption {
            name = "double";
            type = lib.types.functionTo lib.types.int;
            fn = x: x * 2;
            description = "Double a number";
            tests."doubles 5" = {
              args.x = 5;
              expected = 10;
            };
          };
        };

      flake.nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nlib.nixosModules.default
          {
            nlib.enable = true;
            nlib.perLib =
              { lib, mkLibOption, ... }:
              {
                options.lib = mkLibOption {
                  name = "triple";
                  type = lib.types.functionTo lib.types.int;
                  fn = x: x * 3;
                  description = "Triple a number";
                  tests."triples 4" = {
                    args.x = 4;
                    expected = 12;
                  };
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
