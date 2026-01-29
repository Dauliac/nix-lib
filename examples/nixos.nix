# Example: Defining libs in NixOS module
#
# Define at: nlib.lib.<name>
# Use at: config.lib.<name> (within NixOS config)
# Output at: flake.lib.nixos.<name> (collected at flake-parts level)
#
# Usage in nixosConfigurations:
#   modules = [
#     nlib.nixosModules.default
#     {
#       nlib.enable = true;
#       nlib.lib.myHelper = { ... };
#     }
#   ];
#
{ lib, config, ... }:
{
  nlib.enable = true;

  # NixOS-specific lib functions
  nlib.lib.mkSystemdService = {
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

  nlib.lib.enableService = {
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

  nlib.lib.openFirewallPort = {
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

  # ============================================================
  # Usage: Real configs using the libs (for e2e testing)
  # ============================================================

  imports = [
    # Use lib to create a systemd service
    (config.lib.mkSystemdService "example-daemon")

    # Use lib to open firewall ports
    (config.lib.openFirewallPort 8080)
    (config.lib.openFirewallPort 443)

    # Use lib to enable a service
    (config.lib.enableService "openssh")
  ];
}
