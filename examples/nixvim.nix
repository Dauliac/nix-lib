# Example: Defining libs in nixvim module
#
# Define at: nlib.lib.<name>
# Use at: config.nlib.fns.<name> (within nixvim config)
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
{ lib, ... }:
{
  nlib.enable = true;

  # Nixvim-specific lib functions
  nlib.lib.mkKeymap = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        mode,
        key,
        action,
      }:
      {
        keymaps = [
          {
            inherit mode key action;
          }
        ];
      };
    description = "Create a vim keymap";
    tests."creates normal mode keymap" = {
      args.a = {
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
    type = lib.types.functionTo lib.types.attrs;
    fn =
      { name, value }:
      {
        opts.${name} = value;
      };
    description = "Set a vim option";
    tests."sets tabstop" = {
      args.a = {
        name = "tabstop";
        value = 4;
      };
      expected = {
        opts.tabstop = 4;
      };
    };
  };

  # ============================================================
  # Usage Example (in a separate module imported after this one):
  # ============================================================
  #
  # { config, ... }: {
  #   imports = [
  #     (config.nlib.fns.mkKeymap { mode = "n"; key = "<leader>ff"; action = ":Telescope find_files<CR>"; })
  #     (config.nlib.fns.enablePlugin "telescope")
  #     (config.nlib.fns.setOption { name = "number"; value = true; })
  #   ];
  # }
}
