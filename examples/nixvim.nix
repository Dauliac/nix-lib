# Example: Defining libs in nixvim module
#
# These are collected and available at: flake.lib.vim.<name>
#
# Usage in nixvimConfigurations:
#   modules = [
#     nlib.nixvimModules.default
#     {
#       nlib.enable = true;
#       lib.myHelper = { ... };
#     }
#   ];
#
{ lib, ... }:
{
  nlib.enable = true;

  # Nixvim-specific lib functions
  lib.mkKeymap = {
    type = lib.types.functionTo (lib.types.functionTo (lib.types.functionTo lib.types.attrs));
    fn = mode: key: action: {
      keymaps = [
        {
          inherit mode key action;
        }
      ];
    };
    description = "Create a vim keymap";
    tests."creates normal mode keymap" = {
      args = {
        mode = "n";
        key = "<leader>f";
        action = ":Telescope find_files<CR>";
      };
      expected = {
        keymaps = [
          {
            mode = "n";
            key = "<leader>f";
            action = ":Telescope find_files<CR>";
          }
        ];
      };
    };
  };

  lib.enablePlugin = {
    type = lib.types.functionTo lib.types.attrs;
    fn = name: {
      plugins.${name}.enable = true;
    };
    description = "Enable a nixvim plugin";
    tests."enables telescope" = {
      args.name = "telescope";
      expected = {
        plugins.telescope.enable = true;
      };
    };
  };

  lib.setOption = {
    type = lib.types.functionTo (lib.types.functionTo lib.types.attrs);
    fn = name: value: {
      opts.${name} = value;
    };
    description = "Set a vim option";
    tests."sets tabstop" = {
      args = {
        name = "tabstop";
        value = 4;
      };
      expected = {
        opts.tabstop = 4;
      };
    };
  };
}
