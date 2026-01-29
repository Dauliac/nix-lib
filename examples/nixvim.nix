# Example: Defining libs in nixvim module
#
# Define at: nlib.lib.<name>
# Use at: config.lib.<name> (within nixvim config)
# Output at: flake.lib.vim.<name> (collected at flake-parts level)
#
# Usage in nixvimConfigurations:
#   modules = [
#     nlib.nixvimModules.default
#     {
#       nlib.enable = true;
#       nlib.lib.myHelper = { ... };
#     }
#   ];
#
{ lib, config, ... }:
{
  nlib.enable = true;

  # Nixvim-specific lib functions
  nlib.lib.mkKeymap = {
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

  nlib.lib.enablePlugin = {
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

  nlib.lib.setOption = {
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

  # ============================================================
  # Usage: Real configs using the libs (for e2e testing)
  # ============================================================

  imports = [
    # Use lib to create keymaps
    (config.lib.mkKeymap "n" "<leader>ff" ":Telescope find_files<CR>")
    (config.lib.mkKeymap "n" "<leader>fg" ":Telescope live_grep<CR>")
    (config.lib.mkKeymap "n" "<leader>fb" ":Telescope buffers<CR>")
    (config.lib.mkKeymap "n" "<C-s>" ":w<CR>")
    (config.lib.mkKeymap "i" "jk" "<Esc>")

    # Use lib to enable plugins
    (config.lib.enablePlugin "telescope")
    (config.lib.enablePlugin "treesitter")
    (config.lib.enablePlugin "lsp")

    # Use lib to set vim options
    (config.lib.setOption "number" true)
    (config.lib.setOption "relativenumber" true)
    (config.lib.setOption "tabstop" 2)
    (config.lib.setOption "shiftwidth" 2)
    (config.lib.setOption "expandtab" true)
  ];
}
