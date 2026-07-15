# Dev-only inputs — NOT fetched by consumers.
# Provides nixpkgs for building packages and running tests.
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = _: { };
}
