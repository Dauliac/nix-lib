# Example: Defining libs in NixOS module
#
# These are collected and available at: flake.lib.nixos.<name>
#
# Usage in nixosConfigurations:
#   modules = [
#     nlib.nixosModules.default
#     {
#       nlib.enable = true;
#       lib.myHelper = { ... };
#     }
#   ];
#
{ lib, ... }:
{
  nlib.enable = true;

  # NixOS-specific lib functions
  lib.mkSystemdService = {
    type = lib.types.functionTo lib.types.attrs;
    fn = name: {
      systemd.services.${name} = {
        description = "Service ${name}";
        wantedBy = [ "multi-user.target" ];
      };
    };
    description = "Generate a basic systemd service configuration";
    tests."creates nginx service" = {
      args.name = "nginx";
      expected = {
        systemd.services.nginx = {
          description = "Service nginx";
          wantedBy = [ "multi-user.target" ];
        };
      };
    };
  };

  lib.enableService = {
    type = lib.types.functionTo lib.types.attrs;
    fn = name: {
      services.${name}.enable = true;
    };
    description = "Enable a NixOS service";
    tests."enables openssh" = {
      args.name = "openssh";
      expected = {
        services.openssh.enable = true;
      };
    };
  };

  lib.openFirewallPort = {
    type = lib.types.functionTo lib.types.attrs;
    fn = port: {
      networking.firewall.allowedTCPPorts = [ port ];
    };
    description = "Open a TCP port in the firewall";
    tests."opens port 80" = {
      args.port = 80;
      expected = {
        networking.firewall.allowedTCPPorts = [ 80 ];
      };
    };
  };
}
