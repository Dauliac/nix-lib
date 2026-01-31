# Example: Defining libs in NixOS module
#
# Define at: nlib.lib.<name>
# Use at: config.lib.<name> (within NixOS config)
# Output at: flake.lib.nixos.<name> (collected at flake-parts level)
#
# Nested module propagation:
#   When NixOS imports home-manager, home-manager libs are available at:
#     config.lib.home.<libname>
#   This allows using home-manager libs directly in NixOS config!
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
{ lib, ... }:
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
  # Usage Example (in a separate module imported after this one):
  # ============================================================
  #
  # { config, ... }: {
  #   imports = [
  #     # NixOS libs
  #     (config.lib.mkSystemdService "example-daemon")
  #     (config.lib.openFirewallPort 8080)
  #     (config.lib.enableService "openssh")
  #
  #     # Home-manager libs (propagated from nested home-manager config)
  #     # Available when home-manager.nixosModules is imported
  #     # (config.lib.home.mkAlias { name = "ll"; command = "ls -la"; })
  #     # (config.lib.home.enableProgram "starship")
  #
  #     # Vim libs (propagated from home-manager -> nixvim chain)
  #     # Available when nixvim is configured in home-manager users
  #     # (config.lib.home.vim.mkKeymap { mode = "n"; key = "<leader>f"; action = ":Telescope<CR>"; })
  #   ];
  # }
}
