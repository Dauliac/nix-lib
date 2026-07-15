# Supported systems configuration
# Inlined from github:nix-systems/default to avoid an extra input for consumers.
{ ... }:
{
  systems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];
}
