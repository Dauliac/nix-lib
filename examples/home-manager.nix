# Example: Defining libs in home-manager module
#
# Define at: nlib.lib.<name>
# Use at: config.nlib.fns.<name> (within home-manager config)
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
  # Usage Example (in a separate module imported after this one):
  # ============================================================
  #
  # { config, ... }: {
  #   imports = [
  #     (config.nlib.fns.mkAlias { name = "ll"; command = "ls -la"; })
  #     (config.nlib.fns.mkGitConfig { name = "User"; email = "user@example.com"; })
  #     (config.nlib.fns.enableProgram "direnv")
  #   ];
  # }
}
