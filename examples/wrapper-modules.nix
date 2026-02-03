# Example: Defining libs for wrapper module systems
#
# nix-lib supports two wrapper-based module systems:
# - nix-wrapper-modules (github:BirdeeHub/nix-wrapper-modules)
# - Lassulus/wrappers (github:Lassulus/wrappers)
#
# Both create wrapped executables via NixOS-style module evaluation,
# making them compatible with nix-lib's adapter system.
#
# Define at: nix-lib.lib.<name>
# Use at: config.lib.<name> (within wrapper config)
# Output at: flake.lib.wrappers.<name> (collected at flake-parts level)
#
# ============================================================
# Usage with nix-wrapper-modules:
# ============================================================
#
#   # In flake.nix
#   inputs.nix-wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
#
#   # In flake-parts module
#   flake.wrapperConfigurations.myApp =
#     inputs.nix-wrapper-modules.wrappers.alacritty.wrap {
#       inherit pkgs;
#       modules = [
#         nix-lib.wrapperModules.default
#         ./wrapper-modules.nix  # This file
#       ];
#       # Use helpers defined below
#       settings.terminal.shell.program = "${pkgs.zsh}/bin/zsh";
#     };
#
# ============================================================
# Usage with Lassulus/wrappers:
# ============================================================
#
#   # In flake.nix
#   inputs.wrappers.url = "github:Lassulus/wrappers";
#
#   # In flake-parts module
#   flake.wrapperConfigurations.mpv =
#     inputs.wrappers.wrapperModules.mpv.apply {
#       inherit pkgs;
#       modules = [
#         nix-lib.wrapperModules.default
#         ./wrapper-modules.nix  # This file
#       ];
#     };
#
# ============================================================
# Usage with plain evalModules:
# ============================================================
#
#   flake.wrapperConfigurations.custom = nixpkgs.lib.evalModules {
#     modules = [
#       nix-lib.wrapperModules.default
#       ./wrapper-modules.nix
#       {
#         # Your wrapper-specific config here
#       }
#     ];
#   };
#
{ lib, ... }:
{
  nix-lib.enable = true;

  # ============================================================
  # Generic wrapper helpers (work with any wrapper system)
  # ============================================================

  nix-lib.lib.mkWrapperFlags = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        name,
        flags ? [ ],
      }:
      {
        drv.flags.${name} = flags;
      };
    description = "Generate wrapper flags configuration for a binary";
    tests."creates flags for mytool" = {
      args.a = {
        name = "mytool";
        flags = [
          "--config"
          "/etc/mytool.conf"
        ];
      };
      expected = {
        drv.flags.mytool = [
          "--config"
          "/etc/mytool.conf"
        ];
      };
    };
  };

  nix-lib.lib.mkWrapperEnv = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        name,
        env ? { },
      }:
      {
        drv.env.${name} = env;
      };
    description = "Generate wrapper environment variables for a binary";
    tests."creates env for myapp" = {
      args.a = {
        name = "myapp";
        env = {
          HOME = "/tmp/myapp";
          XDG_CONFIG_HOME = "/tmp/myapp/.config";
        };
      };
      expected = {
        drv.env.myapp = {
          HOME = "/tmp/myapp";
          XDG_CONFIG_HOME = "/tmp/myapp/.config";
        };
      };
    };
  };

  nix-lib.lib.mkWrapperPath = {
    type = lib.types.functionTo lib.types.attrs;
    fn = packages: {
      drv.path = packages;
    };
    description = "Add packages to wrapper PATH";
    tests."adds packages to path" = {
      args.packages = [
        "/nix/store/abc-git"
        "/nix/store/def-curl"
      ];
      expected = {
        drv.path = [
          "/nix/store/abc-git"
          "/nix/store/def-curl"
        ];
      };
    };
  };

  # ============================================================
  # Composable wrapper config generator
  # ============================================================

  nix-lib.lib.mkWrapper = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        name,
        flags ? [ ],
        env ? { },
        path ? [ ],
      }:
      {
        drv = {
          flags.${name} = flags;
          env.${name} = env;
          inherit path;
        };
      };
    description = "Generate complete wrapper configuration for a binary";
    tests."creates complete wrapper config" = {
      args.a = {
        name = "nvim";
        flags = [ "--clean" ];
        env = {
          EDITOR = "nvim";
        };
        path = [ "/nix/store/abc-git" ];
      };
      expected = {
        drv = {
          flags.nvim = [ "--clean" ];
          env.nvim = {
            EDITOR = "nvim";
          };
          path = [ "/nix/store/abc-git" ];
        };
      };
    };
  };

  # ============================================================
  # Usage examples (as comments):
  # ============================================================
  #
  # Within a wrapper configuration module:
  #
  # { config, lib, ... }: {
  #   imports = [
  #     # Use individual helpers
  #     (config.lib.mkWrapperFlags { name = "neovim"; flags = [ "--clean" ]; })
  #     (config.lib.mkWrapperEnv { name = "neovim"; env.EDITOR = "nvim"; })
  #
  #     # Or use the combined helper
  #     (config.lib.mkWrapper {
  #       name = "neovim";
  #       flags = [ "--clean" ];
  #       env.EDITOR = "nvim";
  #       path = [ pkgs.git pkgs.ripgrep ];
  #     })
  #   ];
  # }
}
