# Example: Defining libs in system-manager module
#
# Define at: nlib.lib.<name>
# Use at: config.nlib.fns.<name> (within system-manager config)
# Output at: flake.lib.system.<name> (collected at flake-parts level)
#
# Usage in systemConfigs:
#   modules = [
#     nlib.systemManagerModules.default
#     {
#       nlib.enable = true;
#       nlib.lib.myHelper = { ... };
#     }
#   ];
#
{ lib, ... }:
{
  nlib.enable = true;

  # System-manager specific lib functions
  nlib.lib.mkSystemdService = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        name,
        description,
        execStart,
      }:
      {
        systemd.services.${name} = {
          inherit description;
          serviceConfig = {
            ExecStart = execStart;
            Type = "simple";
          };
        };
      };
    description = "Create a systemd service definition";
    tests."creates hello service" = {
      args.x = {
        name = "hello";
        description = "Hello World";
        execStart = "/bin/echo hello";
      };
      expected = {
        systemd.services.hello = {
          description = "Hello World";
          serviceConfig = {
            ExecStart = "/bin/echo hello";
            Type = "simple";
          };
        };
      };
    };
  };

  nlib.lib.mkEnvironmentFile = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        path,
        content,
      }:
      {
        environment.etc.${path}.text = content;
      };
    description = "Create an environment file";
    tests."creates env file" = {
      args.x = {
        path = "myapp/config";
        content = "KEY=value";
      };
      expected = {
        environment.etc."myapp/config".text = "KEY=value";
      };
    };
  };

  nlib.lib.mkEtcLink = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        name,
        source,
      }:
      {
        environment.etc.${name}.source = source;
      };
    description = "Create a symlink in /etc";
    tests."links config" = {
      args.x = {
        name = "myapp.conf";
        source = "/nix/store/abc-config";
      };
      expected = {
        environment.etc."myapp.conf".source = "/nix/store/abc-config";
      };
    };
  };

  # ============================================================
  # Usage Example (in a separate module imported after this one):
  # ============================================================
  #
  # { config, ... }: {
  #   imports = [
  #     (config.nlib.fns.mkSystemdService {
  #       name = "myapp";
  #       description = "My Application";
  #       execStart = "${pkgs.myapp}/bin/myapp";
  #     })
  #     (config.nlib.fns.mkEnvironmentFile {
  #       path = "myapp/env";
  #       content = "DEBUG=true";
  #     })
  #   ];
  # }
}
