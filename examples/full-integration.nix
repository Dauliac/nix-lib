# Example: Full integration - flake.parts -> NixOS -> home-manager
#
# This example shows how to:
# 1. Define libs in flake.parts
# 2. Use those libs in NixOS configuration
# 3. Use those libs in home-manager (nested inside NixOS)
#
# This is a complete flake.nix example:
#
{
  description = "Full nlib integration example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nlib.url = "github:Dauliac/nlib";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nlib,
      home-manager,
      ...
    }:
    nlib.inputs.flake-parts.lib.mkFlake { inputs = { inherit nixpkgs nlib home-manager; }; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [ nlib.flakeModules.default ];

      # ============================================================
      # 1. Define libs in flake.parts (available at flake.lib.*)
      # ============================================================
      lib.flake = {
        # Helper to create consistent user configs
        mkUser = {
          type = nixpkgs.lib.types.functionTo nixpkgs.lib.types.attrs;
          fn = username: {
            users.users.${username} = {
              isNormalUser = true;
              home = "/home/${username}";
              extraGroups = [
                "wheel"
                "networkmanager"
              ];
            };
          };
          description = "Create a standard user configuration";
          tests."creates alice" = {
            args.username = "alice";
            expected = {
              users.users.alice = {
                isNormalUser = true;
                home = "/home/alice";
                extraGroups = [
                  "wheel"
                  "networkmanager"
                ];
              };
            };
          };
        };

        # Helper for home-manager user config
        mkHomeUser = {
          type = nixpkgs.lib.types.functionTo (nixpkgs.lib.types.functionTo nixpkgs.lib.types.attrs);
          fn = username: homeConfig: {
            home-manager.users.${username} = homeConfig;
          };
          description = "Create home-manager config for a user";
          tests."creates bob home" = {
            args = {
              username = "bob";
              homeConfig = {
                home.stateVersion = "24.05";
              };
            };
            expected = {
              home-manager.users.bob = {
                home.stateVersion = "24.05";
              };
            };
          };
        };

        # Reusable shell alias generator
        mkShellAliases = {
          type = nixpkgs.lib.types.functionTo nixpkgs.lib.types.attrs;
          fn = aliases: {
            programs.bash.shellAliases = aliases;
            programs.zsh.shellAliases = aliases;
          };
          description = "Create shell aliases for bash and zsh";
          tests."creates aliases" = {
            args.aliases = {
              ll = "ls -la";
            };
            expected = {
              programs.bash.shellAliases = {
                ll = "ls -la";
              };
              programs.zsh.shellAliases = {
                ll = "ls -la";
              };
            };
          };
        };
      };

      # ============================================================
      # 2. NixOS configuration using the libs
      # ============================================================
      flake.nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Pass flake libs to NixOS modules via specialArgs
        specialArgs = {
          inherit self;
          myLib = self.lib; # flake.lib is available here
        };
        modules = [
          # Include home-manager NixOS module
          home-manager.nixosModules.home-manager

          # Main configuration
          (
            { myLib, ... }:
            {
              # Use flake lib to create user
              imports = [
                (myLib.mkUser "alice")
                (myLib.mkUser "bob")
              ];

              # Configure home-manager
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              # ============================================================
              # 3. Home-manager config using flake libs
              # ============================================================
              home-manager.users.alice =
                { ... }:
                {
                  home.stateVersion = "24.05";

                  # Use flake lib inside home-manager
                  imports = [
                    (myLib.mkShellAliases {
                      ll = "ls -la";
                      la = "ls -A";
                      ".." = "cd ..";
                    })
                  ];

                  programs.git = {
                    enable = true;
                    userName = "Alice";
                    userEmail = "alice@example.com";
                  };
                };

              home-manager.users.bob =
                { ... }:
                {
                  home.stateVersion = "24.05";

                  # Use flake lib inside home-manager
                  imports = [
                    (myLib.mkShellAliases {
                      ll = "eza -la";
                      tree = "eza --tree";
                    })
                  ];
                };

              # Required NixOS options
              system.stateVersion = "24.05";
              fileSystems."/".device = "/dev/sda1";
              boot.loader.grub.device = "/dev/sda";
            }
          )
        ];
      };
    };
}
