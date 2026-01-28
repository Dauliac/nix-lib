# Example: Using nlib functions from outside the flake
#
# Run with:
#   nix eval --impure -f ./example.nix
#
let
  # Load the flake
  flake = builtins.getFlake (toString ./.);

  # Pure flake libs are at flake.lib.<name>
  double = flake.lib.double;

  # Per-system libs are at flake.legacyPackages.<system>.nlib.<name>
  writeGreeting = flake.legacyPackages.x86_64-linux.nlib.writeGreeting;
in
{
  # Use the double function
  doubled = double 21; # → 42

  # Use the writeGreeting function (returns a derivation)
  greetingDrv = writeGreeting "World";

  # Show the derivation name
  greetingName = (writeGreeting "Alice").name; # → "greeting-Alice"
}
