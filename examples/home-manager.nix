# Example: Defining libs in home-manager module
#
# Define at: nlib.lib.<name>
# Use at: config.lib.<name> (within home-manager config)
# Output at: flake.lib.home.<name> (collected at flake-parts level)
#
# Usage in homeConfigurations or as NixOS home-manager module:
#   modules = [
#     nlib.homeModules.default
#     {
#       nlib.enable = true;
#       nlib.lib.myHelper = { ... };
#     }
#   ];
#
{ lib, ... }:
{
  nlib.enable = true;

  # Home-manager specific lib functions
  nlib.lib.mkAlias = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      { name, command }:
      {
        programs.bash.shellAliases.${name} = command;
        programs.zsh.shellAliases.${name} = command;
      };
    description = "Create a shell alias for bash and zsh";
    tests."creates ls alias" = {
      args.a = {
        name = "ll";
        command = "ls -la";
      };
      expected = {
        programs.bash.shellAliases.ll = "ls -la";
        programs.zsh.shellAliases.ll = "ls -la";
      };
    };
  };

  nlib.lib.mkGitConfig = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      { name, email }:
      {
        programs.git = {
          enable = true;
          userName = name;
          userEmail = email;
        };
      };
    description = "Configure git with name and email";
    tests."configures git" = {
      args.a = {
        name = "John";
        email = "john@example.com";
      };
      expected = {
        programs.git = {
          enable = true;
          userName = "John";
          userEmail = "john@example.com";
        };
      };
    };
  };

  nlib.lib.enableProgram = {
    type = lib.types.functionTo lib.types.attrs;
    fn = name: {
      programs.${name}.enable = true;
    };
    description = "Enable a home-manager program";
    tests."enables starship" = {
      args.name = "starship";
      expected = {
        programs.starship.enable = true;
      };
    };
  };

  # ============================================================
  # Vim libs (when nixvim is used inside home-manager)
  # These get propagated up to NixOS at lib.vim.*
  # ============================================================
  nlib.lib.vim.mkKeymap = {
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
    description = "Create a nixvim keymap";
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

  # ============================================================
  # Usage Example (in a separate module imported after this one):
  # ============================================================
  #
  # { config, ... }: {
  #   imports = [
  #     (config.lib.mkAlias { name = "ll"; command = "ls -la"; })
  #     (config.lib.mkGitConfig { name = "User"; email = "user@example.com"; })
  #     (config.lib.enableProgram "direnv")
  #
  #     # Vim libs (when nixvim is configured)
  #     (config.lib.vim.mkKeymap { mode = "n"; key = "<leader>f"; action = ":Telescope<CR>"; })
  #   ];
  # }
}
