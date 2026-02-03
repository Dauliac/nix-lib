# Full integration example - composes ALL nix-lib examples
#
# This flake.parts module demonstrates:
# 1. Flake-level libs (pure, no pkgs)
# 2. Per-system libs (with pkgs)
# 3. NixOS libs with nested home-manager
# 4. Standalone home-manager configuration
# 5. Standalone nixvim configuration
# 6. Darwin configuration
# 7. System-manager configuration (standalone + NixOS integration)
# 8. Wrapper configuration (nix-wrapper-modules style)
#
# Import this single file in your test flake to get all examples.
#
{ inputs, ... }:
let
  inherit (inputs)
    nixpkgs
    home-manager
    nixvim
    nix-darwin
    system-manager
    ;
  # nix-lib is passed via inputs.nlib from the test flake
  nix-lib = inputs.nix-lib or inputs.self;
in
{
  # ============================================================
  # 1. Flake-level libs (pure, no pkgs dependency)
  # ============================================================
  imports = [ ./flake-parts.nix ];

  # ============================================================
  # 2. Per-system libs (with pkgs dependency)
  # ============================================================
  perSystem =
    { ... }:
    {
      imports = [ ./perSystem.nix ];
    };

  # ============================================================
  # 3. NixOS configuration with nested home-manager
  # ============================================================
  flake.nixosConfigurations.test = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      # nix-lib NixOS adapter (libs available at config.lib.*)
      nix-lib.nixosModules.default

      # NixOS-specific libs
      ./nixos.nix

      # Private libs and override patterns
      ./override.nix

      # Home-manager as NixOS module
      home-manager.nixosModules.home-manager

      # NixOS + home-manager configuration
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;

        # Home-manager user with nix-lib libs
        home-manager.users.test =
          { ... }:
          {
            imports = [
              # nix-lib home-manager adapter
              nix-lib.homeModules.default

              # Home-manager specific libs
              ./home-manager.nix

              # Nixvim inside home-manager (no separate nix-lib adapter needed)
              # The home-manager nix-lib adapter handles nixvim libs too
              nixvim.homeManagerModules.nixvim
            ];

            home.stateVersion = "24.05";
          };

        # User configuration for home-manager
        users.users.test = {
          isNormalUser = true;
          home = "/home/test";
          group = "test";
        };
        users.groups.test = { };

        # Required NixOS options
        fileSystems."/".device = "/dev/null";
        boot.loader.grub.device = "/dev/null";
        system.stateVersion = "24.05";
      }
    ];
  };

  # ============================================================
  # 3b. NixOS configuration with user service helpers
  #     (system-manager-style libs for NixOS user services)
  # ============================================================
  flake.nixosConfigurations.test-user-services = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      # nix-lib NixOS adapter
      nix-lib.nixosModules.default

      # User service helpers (mkUserService, mkUserTimer, mkXdgConfigFile)
      ./system-manager-nixos.nix

      # NixOS configuration
      {
        # User configuration
        users.users.test = {
          isNormalUser = true;
          home = "/home/test";
          group = "test";
        };
        users.groups.test = { };

        # Required NixOS options
        fileSystems."/".device = "/dev/null";
        boot.loader.grub.device = "/dev/null";
        system.stateVersion = "24.05";
      }
    ];
  };

  # ============================================================
  # 4. Standalone home-manager configuration
  # ============================================================
  flake.homeConfigurations.test = home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    modules = [
      # nix-lib home-manager adapter
      nix-lib.homeModules.default

      # Home-manager specific libs
      ./home-manager.nix

      # Required home-manager options
      {
        home.username = "test";
        home.homeDirectory = "/home/test";
        home.stateVersion = "24.05";
      }
    ];
  };

  # ============================================================
  # 5. Standalone nixvim configuration
  # ============================================================
  flake.nixvimConfigurations.test = nixvim.lib.evalNixvim {
    modules = [
      # nix-lib nixvim adapter
      nix-lib.nixvimModules.default

      # Nixvim-specific libs
      ./nixvim.nix

      # Required nixvim options
      { nixpkgs.pkgs = nixpkgs.legacyPackages.x86_64-linux; }
    ];
  };

  # ============================================================
  # 6. Darwin configuration (for macOS) with nested home-manager
  # ============================================================
  flake.darwinConfigurations.test = nix-darwin.lib.darwinSystem {
    system = "x86_64-darwin";
    modules = [
      # nix-lib darwin adapter
      nix-lib.darwinModules.default

      # Darwin-specific libs
      ./darwin.nix

      # Home-manager as darwin module
      home-manager.darwinModules.home-manager

      # Darwin + home-manager configuration
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;

        # Home-manager user with nix-lib libs
        home-manager.users.test =
          { ... }:
          {
            imports = [
              # nix-lib home-manager adapter
              nix-lib.homeModules.default

              # Home-manager specific libs (same as NixOS nested)
              ./home-manager.nix

              # Nixvim inside home-manager
              nixvim.homeManagerModules.nixvim
            ];

            home.stateVersion = "24.05";
          };

        # User configuration
        users.users.test = {
          home = "/Users/test";
        };

        # Required darwin options
        nixpkgs.hostPlatform = "x86_64-darwin";
      }
    ];
  };

  # ============================================================
  # 7. Standalone system-manager configuration
  # ============================================================
  flake.systemConfigs.test = system-manager.lib.makeSystemConfig {
    modules = [
      # nix-lib system-manager adapter
      nix-lib.systemManagerModules.default

      # System-manager specific libs
      ./system-manager.nix

      # Required system-manager options
      { nixpkgs.hostPlatform = "x86_64-linux"; }
    ];
  };

  # ============================================================
  # 8. Wrapper configuration (nix-wrapper-modules style)
  # ============================================================
  # nix-wrapper-modules uses lib.evalModules like system-manager
  # This demonstrates nix-lib integration for wrapper-based module systems
  flake.wrapperConfigurations.test = nixpkgs.lib.evalModules {
    modules = [
      # nix-lib wrapper adapter
      nix-lib.wrapperModules.default

      # Wrapper-specific libs
      ./wrapper-modules.nix
    ];
  };
}
