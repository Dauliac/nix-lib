# Example: Defining libs in nixvim module
#
# Define at: nix-lib.lib.<name>
# Use at: config.lib.<name> (within nixvim config)
# Output at: flake.lib.vim.<name> (collected at flake-parts level)
#
# Usage in nixvimConfigurations:
#   modules = [
#     nix-lib.nixvimModules.default
#     {
#       nix-lib.enable = true;
#       nix-lib.lib.myHelper = { ... };
#     }
#   ];
#
{ lib, ... }:
{
  nix-lib.enable = true;

  # Nixvim-specific lib functions
  nix-lib.lib.mkKeymap = {
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

  nix-lib.lib.enablePlugin = {
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

  nix-lib.lib.setOption = {
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
  #     (config.lib.mkKeymap { mode = "n"; key = "<leader>ff"; action = ":Telescope find_files<CR>"; })
  #     (config.lib.enablePlugin "telescope")
  #     (config.lib.setOption { name = "number"; value = true; })
  #   ];
  # }
}
