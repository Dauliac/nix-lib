# Example: Defining libs in nix-wrapper-modules
#
# nix-wrapper-modules creates wrapped executables via the module system.
# This example shows how to define helper libs for wrapper configurations.
#
# Define at: nlib.lib.<name>
# Use at: config.lib.<name> (within wrapper config)
# Output at: flake.lib.wrappers.<name> (collected at flake-parts level)
#
# Usage in wrapperConfigurations:
#   wrapperConfigurations.myWrapper = evalModules {
#     modules = [
#       nlib.wrapperModules.default
#       {
#         nlib.enable = true;
#         nlib.lib.myHelper = { ... };
#       }
#     ];
#   };
#
{ lib, ... }:
{
  nlib.enable = true;

  # Wrapper-specific lib functions
  nlib.lib.mkWrapperFlags = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        name,
        flags ? [ ],
      }:
      {
        drv.flags.${name} = flags;
      };
    description = "Generate wrapper flags configuration";
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

  nlib.lib.mkWrapperEnv = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        name,
        env ? { },
      }:
      {
        drv.env.${name} = env;
      };
    description = "Generate wrapper environment variables";
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

  nlib.lib.mkWrapperPath = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      packages:
      {
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
  # Usage Example (in a wrapper configuration):
  # ============================================================
  #
  # { config, ... }: {
  #   imports = [
  #     (config.lib.mkWrapperFlags { name = "neovim"; flags = [ "--clean" ]; })
  #     (config.lib.mkWrapperEnv { name = "neovim"; env.EDITOR = "nvim"; })
  #   ];
  # }
}
