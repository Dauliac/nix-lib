# Example: Defining libs in home-manager module
#
# These are collected and available at: flake.lib.home.<name>
#
# Usage in homeConfigurations or as NixOS home-manager module:
#   modules = [
#     nlib.homeModules.default
#     {
#       nlib.enable = true;
#       lib.myHelper = { ... };
#     }
#   ];
#
{ lib, config, ... }:
{
  nlib.enable = true;

  # Home-manager specific lib functions
  lib.mkAlias = {
    type = lib.types.functionTo (lib.types.functionTo lib.types.attrs);
    fn = name: command: {
      programs.bash.shellAliases.${name} = command;
      programs.zsh.shellAliases.${name} = command;
    };
    description = "Create a shell alias for bash and zsh";
    tests."creates ls alias" = {
      args = { name = "ll"; command = "ls -la"; };
      expected = {
        programs.bash.shellAliases.ll = "ls -la";
        programs.zsh.shellAliases.ll = "ls -la";
      };
    };
  };

  lib.mkGitConfig = {
    type = lib.types.functionTo (lib.types.functionTo lib.types.attrs);
    fn = name: email: {
      programs.git = {
        enable = true;
        userName = name;
        userEmail = email;
      };
    };
    description = "Configure git with name and email";
    tests."configures git" = {
      args = { name = "John"; email = "john@example.com"; };
      expected = {
        programs.git = {
          enable = true;
          userName = "John";
          userEmail = "john@example.com";
        };
      };
    };
  };

  lib.enableProgram = {
    type = lib.types.functionTo lib.types.attrs;
    fn = name: {
      programs.${name}.enable = true;
    };
    description = "Enable a home-manager program";
    tests."enables starship" = {
      args.name = "starship";
      expected = { programs.starship.enable = true; };
    };
  };
}
