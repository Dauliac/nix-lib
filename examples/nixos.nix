# Example: Defining libs in NixOS module
#
# Define at: nix-lib.lib.<name>
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
#     nix-lib.nixosModules.default
#     {
#       nix-lib.enable = true;
#       nix-lib.lib.myHelper = { ... };
#     }
#   ];
#
{ lib, ... }:
{
  nix-lib.enable = true;

  # NixOS-specific lib functions
  #
  # IMPORTANT: Lib functions should return OPTION-LEVEL values, not top-level
  # NixOS config fragments. This allows using them inside specific option paths
  # without infinite recursion.
  #
  # Good:  fn = name: { description = "..."; wantedBy = [...]; };
  #        Used as: systemd.services.foo = config.lib.mkSystemdService "foo";
  #
  # Bad:   fn = name: { systemd.services.${name} = { ... }; };
  #        Cannot be used at the top level (causes infinite recursion).

  nix-lib.lib.mkSystemdService = {
    type = lib.types.functionTo lib.types.attrs;
    fn = name: {
      description = "Service ${name}";
      wantedBy = [ "multi-user.target" ];
    };
    description = "Generate a basic systemd service configuration";
    tests."creates nginx service" = {
      args.name = "nginx";
      expected = {
        description = "Service nginx";
        wantedBy = [ "multi-user.target" ];
      };
    };
  };

  nix-lib.lib.enableService = {
    type = lib.types.functionTo lib.types.bool;
    fn = _name: true;
    description = "Returns true (for use as services.<name>.enable value)";
    tests."enables openssh" = {
      args._name = "openssh";
      expected = true;
    };
  };

  nix-lib.lib.openFirewallPorts = {
    type = lib.types.functionTo (lib.types.listOf lib.types.port);
    fn = ports: ports;
    description = "Returns a list of TCP ports (for use as networking.firewall.allowedTCPPorts)";
    tests."opens ports" = {
      args.ports = [ 80 443 ];
      expected = [ 80 443 ];
    };
  };

  # ============================================================
  # Usage Example (in a separate module imported after this one):
  # ============================================================
  #
  # IMPORTANT: Do NOT use config.lib.* inside `imports` or at the
  # top level of a module (including lib.mkMerge). The NixOS module
  # system needs to know which options a module sets BEFORE it can
  # build `config`, so referencing config at the top level creates
  # infinite recursion.
  #
  # Instead, use config.lib.* within SPECIFIC option paths:
  #
  # { config, ... }: {
  #   # NixOS libs — used inside specific option paths
  #   systemd.services.example-daemon = config.lib.mkSystemdService "example-daemon";
  #   services.openssh.enable = config.lib.enableService "openssh";
  #   networking.firewall.allowedTCPPorts = config.lib.openFirewallPorts [ 80 443 ];
  #
  #   # Home-manager libs (propagated from nested home-manager config)
  #   # Available when home-manager.nixosModules is imported
  #   # programs.starship.enable = config.lib.home.enableProgram "starship";
  # }
}
