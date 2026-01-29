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
{ lib, config, ... }:
{
  nlib.enable = true;

  # Home-manager specific lib functions
  nlib.lib.mkAlias = {
    type = lib.types.functionTo (lib.types.functionTo lib.types.attrs);
    fn = name: command: {
      programs.bash.shellAliases.${name} = command;
      programs.zsh.shellAliases.${name} = command;
    };
    description = "Create a shell alias for bash and zsh";
    tests."creates ls alias" = {
      args = {
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
      args = {
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
  # Usage: Real configs using the libs (for e2e testing)
  # ============================================================

  imports = [
    # Use lib to create shell aliases
    (config.lib.mkAlias "ll" "ls -la")
    (config.lib.mkAlias "la" "ls -A")
    (config.lib.mkAlias ".." "cd ..")
    (config.lib.mkAlias "g" "git")

    # Use lib to configure git
    (config.lib.mkGitConfig "Test User" "test@example.com")

    # Use lib to enable programs
    (config.lib.enableProgram "direnv")
    (config.lib.enableProgram "fzf")
  ];
}
