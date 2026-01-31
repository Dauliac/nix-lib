# Full integration example - composes ALL nlib examples
#
# This flake.parts module demonstrates:
# 1. Flake-level libs (pure, no pkgs)
# 2. Per-system libs (with pkgs)
# 3. NixOS libs with nested home-manager
# 4. Standalone home-manager configuration
# 5. Standalone nixvim configuration
# 6. Darwin configuration
# 7. System-manager configuration (standalone + NixOS integration)
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
  # nlib is passed via inputs.self from the test flake
  nlib = inputs.self;
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
      # nlib NixOS adapter (libs available at config.lib.*)
      nlib.nixosModules.default

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

        # Home-manager user with nlib libs
        home-manager.users.test =
          { ... }:
          {
            imports = [
              # nlib home-manager adapter
              nlib.homeModules.default

              # Home-manager specific libs
              ./home-manager.nix

              # Nixvim inside home-manager (no separate nlib adapter needed)
              # The home-manager nlib adapter handles nixvim libs too
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
      # nlib NixOS adapter
      nlib.nixosModules.default

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
      # nlib home-manager adapter
      nlib.homeModules.default

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
      # nlib nixvim adapter
      nlib.nixvimModules.default

      # Nixvim-specific libs
      ./nixvim.nix

      # Required nixvim options
      { nixpkgs.pkgs = nixpkgs.legacyPackages.x86_64-linux; }
    ];
  };

  # ============================================================
  # 6. Darwin configuration (for macOS)
  # ============================================================
  flake.darwinConfigurations.test = nix-darwin.lib.darwinSystem {
    system = "x86_64-darwin";
    modules = [
      # nlib darwin adapter
      nlib.darwinModules.default

      # Darwin-specific libs
      ./darwin.nix

      # Required darwin options
      { nixpkgs.hostPlatform = "x86_64-darwin"; }
    ];
  };

  # ============================================================
  # 7. Standalone system-manager configuration
  # ============================================================
  flake.systemConfigs.test = system-manager.lib.makeSystemConfig {
    modules = [
      # nlib system-manager adapter
      nlib.systemManagerModules.default

      # System-manager specific libs
      ./system-manager.nix

      # Required system-manager options
      { nixpkgs.hostPlatform = "x86_64-linux"; }
    ];
  };
}
