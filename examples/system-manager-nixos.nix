# Example: System-manager libs when integrated with NixOS
#
# These are helper functions specifically for using system-manager
# as part of a NixOS configuration, focusing on user-level services
# that complement the NixOS system configuration.
#
{ lib, ... }:
{
  nix-lib.enable = true;

  # NixOS-integrated system-manager helpers
  nix-lib.lib.mkUserService = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        name,
        description,
        execStart,
        wantedBy ? [ "default.target" ],
      }:
      {
        systemd.user.services.${name} = {
          inherit description wantedBy;
          serviceConfig = {
            ExecStart = execStart;
            Type = "simple";
            Restart = "on-failure";
          };
        };
      };
    description = "Create a user-level systemd service";
    tests."creates user backup service" = {
      args.x = {
        name = "backup";
        description = "User backup service";
        execStart = "/usr/bin/rsync -a ~/Documents /backup";
      };
      expected = {
        systemd.user.services.backup = {
          description = "User backup service";
          wantedBy = [ "default.target" ];
          serviceConfig = {
            ExecStart = "/usr/bin/rsync -a ~/Documents /backup";
            Type = "simple";
            Restart = "on-failure";
          };
        };
      };
    };
  };

  nix-lib.lib.mkUserTimer = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        name,
        description,
        onCalendar,
        service,
      }:
      {
        systemd.user.timers.${name} = {
          inherit description;
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = onCalendar;
            Unit = "${service}.service";
            Persistent = true;
          };
        };
      };
    description = "Create a user-level systemd timer";
    tests."creates daily timer" = {
      args.x = {
        name = "daily-backup";
        description = "Daily backup timer";
        onCalendar = "daily";
        service = "backup";
      };
      expected = {
        systemd.user.timers.daily-backup = {
          description = "Daily backup timer";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Unit = "backup.service";
            Persistent = true;
          };
        };
      };
    };
  };

  nix-lib.lib.mkXdgConfigFile = {
    type = lib.types.functionTo lib.types.attrs;
    fn =
      {
        app,
        filename,
        content,
      }:
      {
        xdg.configFile."${app}/${filename}".text = content;
      };
    description = "Create an XDG config file";
    tests."creates app config" = {
      args.x = {
        app = "myapp";
        filename = "config.toml";
        content = "[settings]\nkey = \"value\"";
      };
      expected = {
        xdg.configFile."myapp/config.toml".text = "[settings]\nkey = \"value\"";
      };
    };
  };
}
