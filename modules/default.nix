{ inputs, ... }:

{
  flake = {
    nixosModules.default = import ./nixos { inherit inputs; };
    darwinModules.default = import ./nix-darwin { inherit inputs; };
    homeModules.default = import ./home-manager { inherit inputs; };
  };
}
