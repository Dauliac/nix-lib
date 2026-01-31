# Example: Custom Module System Integration
#
# This example demonstrates how to extend nlib for a custom/fictive module system.
# It shows both creating an adapter and defining a collector for the module system.
#
# The pattern works for any NixOS-style module system:
# - nix-wrapper-modules
# - devenv
# - Your own custom module evaluator
#
# Key steps:
# 1. Create an adapter with mkAdapter
# 2. Define a collector in collectorDefs
# 3. Use the adapter in your module system
# 4. Access collected libs at flake.lib.<namespace>.*
#

# ============================================================
# PART 1: Define the adapter (in your flake outputs)
# ============================================================
#
# In your flake.nix or flake-parts module:
#
# ```nix
# { inputs, ... }:
# let
#   nlib = inputs.nlib;
# in {
#   # Create adapter for your custom module system
#   flake.mySystemModules.default = nlib.lib.nlib.mkAdapter {
#     name = "my-custom-system";
#     namespace = "my";
#   };
# }
# ```
#

# ============================================================
# PART 2: Register a collector (in your flake-parts config)
# ============================================================
#
# In your flake-parts module:
#
# ```nix
# { ... }:
# {
#   nlib.collectorDefs.my = {
#     pathType = "flat";                    # or "perSystem"
#     configPath = [ "myConfigurations" ];  # flake.myConfigurations.*
#     namespace = "my";                     # flake.lib.my.*
#     description = "My custom module system libs";
#   };
# }
# ```
#

# ============================================================
# PART 3: Example lib definitions for the custom system
# ============================================================

{ lib, ... }:
{
  nlib.enable = true;

  # Define libs specific to your module system
  nlib.lib.mkComponent = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        name,
        version ? "1.0.0",
        dependencies ? [ ],
      }:
      {
        components.${name} = {
          inherit version;
          deps = dependencies;
        };
      };
    description = "Create a component definition for my-custom-system";
    tests."creates component" = {
      args.a = {
        name = "mylib";
        version = "2.0.0";
        dependencies = [
          "base"
          "utils"
        ];
      };
      expected = {
        components.mylib = {
          version = "2.0.0";
          deps = [
            "base"
            "utils"
          ];
        };
      };
    };
  };

  nlib.lib.mkPlugin = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        name,
        src,
        config ? { },
      }:
      {
        plugins.${name} = {
          inherit src;
          settings = config;
        };
      };
    description = "Create a plugin configuration";
    tests."creates plugin" = {
      args.a = {
        name = "formatter";
        src = "/nix/store/abc-formatter";
        config = {
          indent = 2;
        };
      };
      expected = {
        plugins.formatter = {
          src = "/nix/store/abc-formatter";
          settings = {
            indent = 2;
          };
        };
      };
    };
  };

  nlib.lib.enableFeature = {
    type = lib.types.functionTo lib.types.attrs;
    fn = feature: {
      features.${feature}.enable = true;
    };
    description = "Enable a feature flag";
    tests."enables debug" = {
      args.feature = "debug";
      expected = {
        features.debug.enable = true;
      };
    };
  };
}

# ============================================================
# PART 4: Using the adapter in your module system
# ============================================================
#
# In your module system evaluation:
#
# ```nix
# # Evaluate a configuration
# flake.myConfigurations.production = lib.evalModules {
#   modules = [
#     # Import nlib adapter
#     nlib.mySystemModules.default
#
#     # Your lib definitions
#     ./custom-module-system.nix  # (this file)
#
#     # Your actual config
#     {
#       # Use libs from config.lib.*
#       imports = [
#         (config.lib.mkComponent { name = "api"; version = "3.0.0"; })
#         (config.lib.mkPlugin { name = "auth"; src = pkgs.authPlugin; })
#         (config.lib.enableFeature "logging")
#       ];
#     }
#   ];
# };
# ```
#

# ============================================================
# PART 5: Accessing collected libs at flake level
# ============================================================
#
# After evaluation, libs are collected and available at:
#
# - flake.lib.my.mkComponent
# - flake.lib.my.mkPlugin
# - flake.lib.my.enableFeature
#
# You can use them anywhere in your flake:
#
# ```nix
# { inputs, ... }: {
#   someOutput = inputs.self.lib.my.mkComponent {
#     name = "shared";
#     version = "1.0.0";
#   };
# }
# ```
